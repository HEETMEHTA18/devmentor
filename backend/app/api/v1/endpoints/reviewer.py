import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import httpx

from app.api.deps import get_current_user_id
from app.core.config import settings
from app.services.openclaw_service import OpenClawService

logger = logging.getLogger(__name__)
router = APIRouter()
_openclaw_service = OpenClawService()


class ReviewRequest(BaseModel):
    repo_url: str
    branch: str = "main"


class ReviewResponse(BaseModel):
    success: bool
    security_score: int
    performance_score: int
    architecture_score: int
    maintainability_score: int
    summary: str
    issues: list[str]


@router.post("/", response_model=ReviewResponse)
async def run_continuous_code_review(
    request: ReviewRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Continuous Code Reviewer: Analyzes architecture, security, performance, accessibility.
    Dispatches task to OpenClaw to analyze the repo, then uses Gemini to generate standard scores.
    """
    if not settings.groq_api_key:
        raise HTTPException(status_code=500, detail="LLM API key not configured")

    # 1. Ask OpenClaw to clone and analyze the codebase structure
    logger.info(f"Dispatching Code Review for {request.repo_url}")
    claw_task = f"Clone {request.repo_url} branch {request.branch}. Analyze the architecture, dependencies, and code quality. Do not modify files. Just print a summary of the tech stack, major files, and obvious code smells."
    claw_result = await _openclaw_service.execute_task(
        repo_url=request.repo_url,
        task_description=claw_task,
        branch_name=request.branch,
    )

    # Extract the raw output from OpenClaw (the file tree / analysis)
    raw_analysis = str(claw_result.get("message", claw_result))

    # 2. Use Gemini/Llama to generate the exact scores and detailed review
    system_prompt = (
        "You are the AutoDevs Continuous Code Reviewer (Principal Staff Engineer level).\n"
        "You will receive a raw analysis of a repository.\n"
        "You must generate a strict JSON response containing:\n"
        "{\n"
        '  "security_score": int (0-100),\n'
        '  "performance_score": int (0-100),\n'
        '  "architecture_score": int (0-100),\n'
        '  "maintainability_score": int (0-100),\n'
        '  "summary": "String explaining the overall health",\n'
        '  "issues": ["List of string issues/recommendations"]\n'
        "}\n"
        "Do not output anything outside of the JSON block."
    )

    url = "https://api.groq.com/openai/v1/chat/completions"
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json={
                    "model": "llama-3.1-8b-instant",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {
                            "role": "user",
                            "content": f"Review this repository analysis:\n\n{raw_analysis}",
                        },
                    ],
                    "response_format": {"type": "json_object"},
                },
                headers={
                    "Authorization": f"Bearer {settings.groq_api_key}",
                    "Content-Type": "application/json",
                },
                timeout=45.0,
            )

            if response.status_code == 200:
                data = response.json()
                import json

                try:
                    review_data = json.loads(data["choices"][0]["message"]["content"])
                    return ReviewResponse(
                        success=True,
                        security_score=review_data.get("security_score", 0),
                        performance_score=review_data.get("performance_score", 0),
                        architecture_score=review_data.get("architecture_score", 0),
                        maintainability_score=review_data.get(
                            "maintainability_score", 0
                        ),
                        summary=review_data.get("summary", "Analysis complete."),
                        issues=review_data.get("issues", []),
                    )
                except json.JSONDecodeError:
                    raise HTTPException(
                        status_code=500,
                        detail="LLM failed to output valid JSON for review.",
                    )
            else:
                logger.error(f"API Error: {response.text}")
                raise HTTPException(status_code=500, detail="Code reviewer AI failed")

        except Exception as e:
            logger.error(f"Code Reviewer Exception: {e}")
            raise HTTPException(status_code=500, detail=str(e))
