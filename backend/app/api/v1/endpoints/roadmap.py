import httpx
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.core.config import settings
from app.models.entities import Repository

router = APIRouter()


@router.post('/generate')
async def generate_roadmap(user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    from sqlalchemy import select
    stmt = select(Repository).where(Repository.user_id == user_id)
    repos = db.scalars(stmt).all()
    repo_list_str = ", ".join([r.full_name for r in repos]) if repos else "No repositories synced yet"

    prompt = (
        "Generate a structured, professional 5-step career roadmap for a developer. "
        f"Based on their synced GitHub repositories: {repo_list_str}. "
        "Return the output as a JSON object containing a key 'milestones' which is a list of milestones with 'title' and 'description' keys. "
        "No extra conversational text."
    )

    if settings.groq_api_key:
        url = "https://api.groq.com/openai/v1/chat/completions"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    url,
                    json={
                        "model": "llama-3.1-8b-instant",
                        "messages": [
                            {"role": "user", "content": prompt}
                        ],
                        "response_format": {"type": "json_object"}
                    },
                    headers={
                        "Authorization": f"Bearer {settings.groq_api_key}",
                        "Content-Type": "application/json"
                    },
                    timeout=30.0
                )
                if response.status_code == 200:
                    data = response.json()
                    reply = data['choices'][0]['message']['content']
                    import json
                    res_json = json.loads(reply)
                    milestones = res_json.get('milestones', [])
                    return {'user_id': user_id, 'milestones': milestones}
            except Exception:
                pass

    api_key = settings.gemini_api_key
    if not api_key:
        return {'message': 'Roadmap generated (Mock)', 'milestones': ['Testing', 'Architecture', 'CI/CD']}

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json={
                    "contents": [{"parts": [{"text": prompt}]}]
                },
                headers={"Content-Type": "application/json"},
                timeout=30.0
            )
            if response.status_code == 200:
                data = response.json()
                reply = data['candidates'][0]['content']['parts'][0]['text']
                clean_reply = reply.replace("```json", "").replace("```", "").strip()
                import json
                res_json = json.loads(clean_reply)
                milestones = res_json.get('milestones', res_json) if isinstance(res_json, dict) else res_json
                return {'user_id': user_id, 'milestones': milestones}
            else:
                return {'user_id': user_id, 'milestones': [{'title': 'Learn Software Architecture', 'description': 'Deepen your knowledge of architectural design patterns.'}]}
        except Exception:
            return {'user_id': user_id, 'milestones': [{'title': 'Learn Software Architecture', 'description': 'Deepen your knowledge of architectural design patterns.'}]}


@router.get('/current')
def current_roadmap(user_id: str = Depends(get_current_user_id)):
    return {
        'user_id': user_id,
        'title': 'Flutter to Senior Mobile Engineer',
        'milestones': ['Testing', 'Architecture', 'CI/CD'],
    }

