"""
NeuroSpace — Voice Command Router
=================================
Parses transcribed speech into assistant actions for overlay workflows.
"""

from fastapi import APIRouter

from models.schemas import VoiceCommandRequest, VoiceCommandResponse
from services.voice_intent import parse_intent

router = APIRouter()


def _local_fallback_intent(text: str) -> dict:
    """Simple deterministic fallback to keep voice commands useful offline/failure."""
    normalized = text.lower().strip()

    if any(k in normalized for k in ["read", "read aloud", "speak"]):
        return {
            "action_type": "feature",
            "feature_name": "read",
            "dom_action": None,
            "speak_message": None,
            "normalized_command": normalized,
        }

    if any(k in normalized for k in ["summarize", "summary"]):
        return {
            "action_type": "feature",
            "feature_name": "summarize",
            "dom_action": None,
            "speak_message": None,
            "normalized_command": normalized,
        }

    if any(k in normalized for k in ["simplify", "simple", "easy read"]):
        return {
            "action_type": "feature",
            "feature_name": "simplify",
            "dom_action": None,
            "speak_message": None,
            "normalized_command": normalized,
        }

    if any(k in normalized for k in ["scan", "ocr", "camera"]):
        return {
            "action_type": "feature",
            "feature_name": "scan",
            "dom_action": None,
            "speak_message": None,
            "normalized_command": normalized,
        }

    if any(k in normalized for k in ["close", "minimize", "hide bubble"]):
        return {
            "action_type": "feature",
            "feature_name": "close",
            "dom_action": None,
            "speak_message": None,
            "normalized_command": normalized,
        }

    return {
        "action_type": "speak",
        "feature_name": None,
        "dom_action": None,
        "speak_message": "Sorry, I could not understand that command.",
        "normalized_command": normalized,
    }


@router.post("/voice/intent", response_model=VoiceCommandResponse)
async def voice_intent(request: VoiceCommandRequest):
    """
    Parse voice transcript into a structured assistant action.
    Uses LLM parser first, then deterministic fallback.
    """
    try:
        parsed = parse_intent(request.transcription)
    except Exception:
        parsed = None

    if not parsed or not isinstance(parsed, dict):
        parsed = _local_fallback_intent(request.transcription)
    else:
        parsed.setdefault("normalized_command", request.transcription.lower().strip())

    return VoiceCommandResponse(**parsed)
