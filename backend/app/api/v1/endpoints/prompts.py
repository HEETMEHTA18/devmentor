import json
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from typing import List, Optional

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import PromptHistory
from app.api.v1.endpoints.advanced import call_ai_json

logger = logging.getLogger(__name__)
router = APIRouter()


class PromptEventRequest(BaseModel):
    original_prompt: str
    project_name: Optional[str] = None
    file_context: Optional[str] = None


@router.post("/event")
async def receive_prompt_event(
    payload: PromptEventRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Receive an AutoDevs event, refine the prompt, score it, extract tech/workflow, and save it.
    """
    if not payload.original_prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")
        
    ai_prompt = (
        f"You are a Prompt Intelligence Analyzer. Analyze the following prompt used by a developer:\n\n"
        f"Prompt: {payload.original_prompt}\n"
        f"Project Name Context: {payload.project_name or 'N/A'}\n"
        f"File Context: {payload.file_context or 'N/A'}\n\n"
        f"Perform the following tasks:\n"
        f"1. Refine and upgrade the original prompt to be much more clear, professional, structured (with instructions/placeholders) and effective for an AI coding assistant.\n"
        f"2. Score the original prompt from 0 to 100 based on its clarity, specificity, context, and structural quality.\n"
        f"3. Extract technologies, languages, libraries or frameworks referenced or relevant (e.g. Flutter, FastAPI, python, react). Return as a list of names.\n"
        f"4. Detect the developer workflow category. Choose exactly one from: Debugging, Refactoring, Feature Building, Testing, DevOps, Architecture, Documentation.\n\n"
        f"Return your response strictly as a JSON object with these exact keys:\n"
        f"{{\n"
        f'  "refined_prompt": "upgraded prompt content here",\n'
        f'  "score": 85,\n'
        f'  "technologies": ["Python", "FastAPI"],\n'
        f'  "workflow": "Feature Building"\n'
        f"}}"
    )
    
    ai_res = {}
    try:
        ai_res = await call_ai_json(ai_prompt)
    except Exception as e:
        logger.error(f"Error calling AI for prompt analysis: {e}")
        
    refined_prompt = ai_res.get("refined_prompt") or f"// Refined:\n{payload.original_prompt}\n\n(Specify detailed requirements for better results.)"
    score = ai_res.get("score") or 50
    techs_list = ai_res.get("technologies") or []
    workflow = ai_res.get("workflow") or "Development"
    
    # Format technologies list to comma separated string
    technologies_str = ", ".join(techs_list) if techs_list else "General"
    
    db_prompt = PromptHistory(
        user_id=user_id,
        original_prompt=payload.original_prompt,
        refined_prompt=refined_prompt,
        score=score,
        technologies=technologies_str,
        workflow=workflow,
        project_name=payload.project_name
    )
    
    db.add(db_prompt)
    db.commit()
    db.refresh(db_prompt)
    
    return {
        "id": db_prompt.id,
        "user_id": db_prompt.user_id,
        "original_prompt": db_prompt.original_prompt,
        "refined_prompt": db_prompt.refined_prompt,
        "score": db_prompt.score,
        "technologies": techs_list,
        "workflow": db_prompt.workflow,
        "project_name": db_prompt.project_name,
        "created_at": db_prompt.created_at.isoformat()
    }


@router.get("/history")
def get_prompt_history(
    q: Optional[str] = None,
    workflow: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    List prompt history for the authenticated user, supporting optional search queries and workflow filters.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    if q:
        search_filter = f"%{q}%"
        stmt = stmt.where(
            PromptHistory.original_prompt.like(search_filter) |
            PromptHistory.refined_prompt.like(search_filter) |
            PromptHistory.technologies.like(search_filter)
        )
    if workflow:
        stmt = stmt.where(PromptHistory.workflow == workflow)
        
    stmt = stmt.order_by(PromptHistory.created_at.desc())
    prompts = db.scalars(stmt).all()
    
    result = []
    for p in prompts:
        result.append({
            "id": p.id,
            "original_prompt": p.original_prompt,
            "refined_prompt": p.refined_prompt,
            "score": p.score,
            "technologies": [t.strip() for t in p.technologies.split(",")] if p.technologies else [],
            "workflow": p.workflow,
            "project_name": p.project_name,
            "created_at": p.created_at.isoformat()
        })
    return result


@router.get("/analytics")
def get_prompt_analytics(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Generate prompt quality and developer habits analytics.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    prompts = db.scalars(stmt).all()
    
    if not prompts:
        return {
            "total_prompts": 0,
            "average_score": 0,
            "workflow_counts": {},
            "top_technologies": [],
            "score_history": []
        }
        
    total_prompts = len(prompts)
    avg_score = round(sum(p.score for p in prompts) / total_prompts, 1)
    
    # Calculate workflow counts
    workflow_counts = {}
    for p in prompts:
        workflow_counts[p.workflow] = workflow_counts.get(p.workflow, 0) + 1
        
    # Calculate technology breakdown
    tech_counts = {}
    for p in prompts:
        if p.technologies:
            for t in p.technologies.split(","):
                clean_t = t.strip()
                if clean_t and clean_t != "General":
                    tech_counts[clean_t] = tech_counts.get(clean_t, 0) + 1
                    
    sorted_techs = sorted(tech_counts.items(), key=lambda x: x[1], reverse=True)
    top_technologies = [{"name": name, "count": count} for name, count in sorted_techs[:5]]
    
    # Recent scores (up to 10) for trend line
    recent_prompts = sorted(prompts, key=lambda x: x.created_at)
    score_history = [
        {
            "date": p.created_at.strftime("%m-%d"),
            "score": p.score
        }
        for p in recent_prompts[-10:]
    ]
    
    return {
        "total_prompts": total_prompts,
        "average_score": avg_score,
        "workflow_counts": workflow_counts,
        "top_technologies": top_technologies,
        "score_history": score_history
    }


@router.get("/recommendations")
async def get_prompt_recommendations(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Generate learning recommendations based on developer's prompt patterns and detected skill gaps.
    """
    stmt = select(PromptHistory).where(PromptHistory.user_id == user_id)
    prompts = db.scalars(stmt).all()
    
    if not prompts:
        return {
            "recommendations": [
                {
                    "title": "Introduction to Effective Prompting",
                    "description": "Start tracking your coding prompts using the AutoDevs CLI to unlock detailed skill gaps and tailored learning paths.",
                    "tags": ["Prompting", "Basics"],
                    "url": "https://github.com/phodal/auto-dev"
                }
            ]
        }
        
    # Extract low-scoring workflows or technologies
    low_prompts = [p for p in prompts if p.score < 75]
    workflow_issues = {}
    for p in low_prompts:
        workflow_issues[p.workflow] = workflow_issues.get(p.workflow, 0) + 1
        
    worst_workflow = max(workflow_issues.items(), key=lambda x: x[1])[0] if workflow_issues else None
    
    # Extract overall techs
    tech_set = set()
    for p in prompts:
        if p.technologies:
            for t in p.technologies.split(","):
                clean_t = t.strip()
                if clean_t and clean_t != "General":
                    tech_set.add(clean_t)
                    
    techs_str = ", ".join(tech_set) if tech_set else "coding and architecture"
    
    # Request AI for personalized learning roadmap/resources
    ai_prompt = (
        f"You are a developer coach. Based on the developer's prompt history, they have low scores in "
        f"the workflow '{worst_workflow or 'general coding'}'. Their primary tech stack includes: {techs_str}.\n\n"
        f"Generate 3-4 actionable, high-quality learning recommendations (tutorials, topics, best practices) to improve. "
        f"For example, if they have low scores in Refactoring, suggest Clean Code principles. If they use Flutter, recommend specific Flutter design patterns.\n\n"
        f"Return your response strictly as a JSON object with this exact key:\n"
        f"{{\n"
        f'  "recommendations": [\n'
        f'    {{\n'
        f'      "title": "Title of the course or topic",\n'
        f'      "description": "Detailed explanation of why they need this and what they will learn.",\n'
        f'      "tags": ["Flutter", "Clean Architecture"],\n'
        f'      "url": "https://github.com/..."\n'
        f'    }}\n'
        f'  ]\n'
        f"}}"
    )
    
    res = {}
    try:
        res = await call_ai_json(ai_prompt)
    except Exception as e:
        logger.error(f"Error in prompt recommendations: {e}")
        
    recommendations = res.get("recommendations")
    if not recommendations:
        # Static fallback
        recommendations = [
            {
                "title": f"Mastering {worst_workflow or 'Development'} Workflows",
                "description": f"Learn industry best practices for {worst_workflow or 'general coding'} including structuring code reviews and refining agent instructions.",
                "tags": [worst_workflow or "General", "Best Practices"],
                "url": "https://github.com/phodal/auto-dev"
            }
        ]
        
    return {"recommendations": recommendations}
