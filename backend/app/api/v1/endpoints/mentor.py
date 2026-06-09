import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import Repository, TechNews, GithubProfile

router = APIRouter()
logger = logging.getLogger(__name__)

PROVIDER_AUTO = "auto"
PROVIDER_STUB = "stub"
SUPPORTED_AI_PROVIDERS = ("groq", "gemini")


class MentorMessageRequest(BaseModel):
    message: str
    context_window_tokens: int | None = None
    client_context: str | None = None


def _normalize_ai_provider() -> str:
    provider = (settings.ai_provider or PROVIDER_AUTO).strip().lower()
    if provider in (*SUPPORTED_AI_PROVIDERS, PROVIDER_AUTO, PROVIDER_STUB):
        return provider

    logger.warning("Unsupported AI_PROVIDER=%s; falling back to auto", provider)
    return PROVIDER_AUTO


def _available_ai_providers() -> list[str]:
    providers = []
    if settings.groq_api_key:
        providers.append("groq")
    if settings.gemini_api_key:
        providers.append("gemini")
    return providers


def _selected_ai_providers() -> list[str]:
    provider = _normalize_ai_provider()
    available = _available_ai_providers()
    if provider == PROVIDER_STUB:
        return []
    if provider == PROVIDER_AUTO:
        return available
    if provider not in available:
        logger.warning(
            "AI_PROVIDER=%s was selected but its API key is not configured; falling back to available providers",
            provider,
        )
        return available
    return [provider] + [candidate for candidate in available if candidate != provider]


def _provider_status() -> dict:
    selected = _selected_ai_providers()
    return {
        "mode": _normalize_ai_provider(),
        "configured": {
            "groq": bool(settings.groq_api_key),
            "gemini": bool(settings.gemini_api_key),
        },
        "available": _available_ai_providers(),
        "selected": selected[0] if selected else PROVIDER_STUB,
        "fallback_order": selected,
        "models": {
            "groq": settings.groq_model,
            "gemini": settings.gemini_model,
        },
    }


async def search_github_repositories(
    topic_query: str, access_token: str = None
) -> list:
    """
    Search GitHub repositories for a given topic or keyword, sorted by stars.
    """
    q = topic_query.lower().strip()
    if "cybersecurity" in q or "cyber security" in q:
        search_q = "topic:cybersecurity"
    elif "data science" in q or "datascience" in q:
        search_q = "topic:data-science"
    elif "machine learning" in q or "machinelearning" in q:
        search_q = "topic:machine-learning"
    elif "artificial intelligence" in q or " ai " in q or q.startswith("ai "):
        search_q = "topic:artificial-intelligence"
    elif "web dev" in q or "web development" in q:
        search_q = "topic:web-development"
    elif "flutter" in q or "mobile dev" in q:
        search_q = "topic:flutter"
    else:
        search_q = q

    url = f"https://api.github.com/search/repositories?q={search_q}&sort=stars&order=desc&per_page=5"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "DevMentor-App",
    }
    if access_token:
        headers["Authorization"] = f"token {access_token}"

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=12.0)
            if response.status_code == 200:
                items = response.json().get("items", [])
                return [
                    {
                        "name": item.get("name"),
                        "full_name": item.get("full_name"),
                        "description": item.get("description")
                        or "No description provided.",
                        "stars": item.get("stargazers_count", 0),
                        "html_url": item.get("html_url"),
                        "language": item.get("language"),
                    }
                    for item in items
                ]
        except Exception as e:
            import logging

            logging.getLogger(__name__).error(f"Error calling GitHub Search API: {e}")
    return []


@router.get("/provider/status")
async def mentor_provider_status():
    return _provider_status()


@router.post("/chat")
async def mentor_chat(
    payload: MentorMessageRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    # 1. Fetch user repositories from db to build contextual developer profile
    stmt = select(Repository).where(Repository.user_id == user_id)
    repos = db.scalars(stmt).all()
    repo_list_str = (
        ", ".join([r.full_name for r in repos])
        if repos
        else "No repositories synced yet"
    )

    # 2. Get user's github profile to see if we have access token
    profile_stmt = select(GithubProfile).where(GithubProfile.user_id == user_id)
    profile = db.scalar(profile_stmt)
    access_token = profile.access_token if profile else None

    # 3. Detect if they are asking for top repositories
    msg_lower = payload.message.lower()
    github_context = ""
    if any(
        k in msg_lower
        for k in [
            "top repo",
            "best repo",
            "popular repo",
            "excelling repo",
            "top github",
            "best github",
            "popular github",
            "excelling github",
        ]
    ):
        # Determine the topic
        topic = "data-science"
        if "cybersecurity" in msg_lower or "cyber security" in msg_lower:
            topic = "cybersecurity"
        elif "machine learning" in msg_lower or "machinelearning" in msg_lower:
            topic = "machine-learning"
        elif "ai" in msg_lower or "artificial intelligence" in msg_lower:
            topic = "artificial-intelligence"
        elif "web dev" in msg_lower or "web development" in msg_lower:
            topic = "web-development"
        elif "mobile" in msg_lower or "flutter" in msg_lower:
            topic = "flutter"

        # Query Github Search API
        search_results = await search_github_repositories(topic, access_token)
        if search_results:
            github_context = (
                "\nReal-time Top Repositories in "
                + topic.replace("-", " ")
                + " from GitHub:\n"
            )
            for r in search_results:
                github_context += f"- {r['full_name']} ({r['stars']} stars): {r['description']} (Link: {r['html_url']})\n"
        else:
            github_context = f"\nNo real-time repositories found for topic {topic}.\n"

    # 4. Fetch the latest scanned tech news
    news_stmt = select(TechNews).order_by(TechNews.scanned_at.desc()).limit(8)
    news_records = db.scalars(news_stmt).all()
    news_context = ""
    if news_records:
        news_context = "\nReal-time 24/7 Scanned Tech News Headlines:\n"
        for n in news_records:
            news_context += f"- {n.title} (Link: {n.link})\n"
    else:
        news_context = "\nNo real-time tech news scanned yet.\n"

    requested_context_window = max(
        1000, min(payload.context_window_tokens or 8000, 128000)
    )
    client_context = (payload.client_context or "").strip()
    if len(client_context) > 12000:
        client_context = client_context[:12000] + "\n[Client context truncated]"

    # 5. Build the system prompt with strict concise plaintext rules
    system_prompt = (
        "You are DevMentor, a highly specialized developer growth coach. Your role is strictly to analyze "
        "the user's GitHub activity, repositories, commits, and skill gaps, and provide career roadmaps "
        "and development mentoring. You MUST NOT answer any general knowledge, coding help unrelated to their "
        "profile, or non-mentoring questions. If the user asks anything outside of DevMentor guidance, "
        "politely decline and steer them back to their career development.\n\n"
        "CRITICAL RESPONSE STYLE GUIDELINES:\n"
        "- Keep your answers extremely short, concise, and punchy (maximum of 2-3 sentences, or a quick list).\n"
        "- Do NOT use markdown bolding (e.g. never use '**').\n"
        "- Do NOT use markdown headers (e.g. never use '#', '##', or '###').\n"
        "- Write in simple, clean, plain text that fits easily in a small chat bubble. Keep it engaging so the user doesn't get bored.\n"
        "- Present links as raw clean URLs (e.g. https://github.com/...), not markdown format.\n\n"
        "You have access to real-time information below. When the user asks about trending repos, tech news, "
        "what's happening in tech, or roadmaps, you MUST use the real data provided below to answer them. DO NOT "
        "make up mock names or links. Provide the real repository names, stars, descriptions, and hyperlinks.\n\n"
        f"Context - Synced User Repositories: {repo_list_str}\n"
        f"Requested Context Window Budget: {requested_context_window} tokens\n"
        f"Client Provided Context:\n{client_context or 'No extra client context supplied.'}\n"
        f"{github_context}"
        f"{news_context}\n"
        "Always recommend actionable learning steps based on these real-time tech trends and repositories."
    )

    def clean_response(text: str) -> str:
        # Strip bold symbols and header symbols
        cleaned = (
            text.replace("**", "").replace("###", "").replace("##", "").replace("#", "")
        )
        # Replace common markdown list markers with clean dashes if needed
        return cleaned.strip()

    async def call_groq() -> str | None:
        url = "https://api.groq.com/openai/v1/chat/completions"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url,
                    json={
                        "model": settings.groq_model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": payload.message},
                        ],
                    },
                    headers={
                        "Authorization": f"Bearer {settings.groq_api_key}",
                        "Content-Type": "application/json",
                    },
                    timeout=settings.ai_request_timeout_seconds,
                )
                if response.status_code == 200:
                    data = response.json()
                    return data["choices"][0]["message"]["content"]
                else:
                    logger.error("Groq API error: %s", response.text)
            except Exception as e:
                logger.error("Error calling Groq: %s", e)
        return None

    async def call_gemini() -> str | None:
        api_key = settings.gemini_api_key
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.gemini_model}:generateContent?key={api_key}"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url,
                    json={
                        "contents": [
                            {
                                "parts": [
                                    {
                                        "text": f"{system_prompt}\nUser message: {payload.message}"
                                    }
                                ]
                            }
                        ]
                    },
                    headers={"Content-Type": "application/json"},
                    timeout=settings.ai_request_timeout_seconds,
                )
                if response.status_code == 200:
                    data = response.json()
                    try:
                        return data["candidates"][0]["content"]["parts"][0]["text"]
                    except (KeyError, IndexError):
                        logger.error("Malformed Gemini response")
                else:
                    logger.error("Gemini API error: %s", response.text)
            except Exception as e:
                logger.error("Error calling Gemini: %s", e)
        return None

    # 6. Call AI API
    for provider in _selected_ai_providers():
        reply = await call_groq() if provider == "groq" else await call_gemini()
        if reply:
            return {
                "user_id": user_id,
                "assistant_message": clean_response(reply),
            }

    # Ultimate fallback if no keys exist or if both API calls failed
    return {
        "user_id": user_id,
        "assistant_message": f"[Stub Mode] Synced repos: {repo_list_str}. You asked: {payload.message}",
    }
