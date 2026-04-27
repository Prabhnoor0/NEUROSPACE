"""
NeuroSpace — Simplify Router
================================
Handles text simplification from shared content, pasted text,
or captured images (Snap-to-Understand).
"""

import logging
from fastapi import APIRouter, HTTPException

from models.schemas import (
    SimplifyRequest,
    SimplifyResponse,
    ImageAnalyzeRequest,
    LessonModule,
    LessonResponse,
)
from services import gemini_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Simplify Text
# ============================================

@router.post("/simplify", response_model=SimplifyResponse)
async def simplify_text(request: SimplifyRequest):
    """
    Simplify complex text based on the user's neuro-profile.

    Used when:
    - User shares text from Chrome/PDF via Share Sheet
    - User pastes text directly into the app
    - User wants to simplify a saved document
    """
    try:
        # Call Gemini to simplify
        lesson_data = await gemini_service.simplify_text(
            text=request.text,
            profile=request.user_profile.value,
        )

        modules = [
            LessonModule(**mod) for mod in lesson_data.get("modules", [])
        ]

        return SimplifyResponse(
            original_length=len(request.text),
            simplified_text=lesson_data.get("tts_text", ""),
            modules=modules,
            tts_text=lesson_data.get("tts_text"),
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Text simplification failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to simplify text: {str(e)}"
        )


@router.post("/summarize", response_model=SimplifyResponse)
async def summarize_text(request: SimplifyRequest):
    """
    Dedicated summarize endpoint for assistant quick actions.
    Currently uses same adaptive simplify pipeline for concise output.
    """
    return await simplify_text(request)


# ============================================
# Analyze Image (Snap-to-Understand)
# ============================================

@router.post("/analyze-image", response_model=LessonResponse)
async def analyze_image(request: ImageAnalyzeRequest):
    """
    Analyze an image (photo of textbook, diagram, whiteboard) and
    generate an adaptive lesson from its content.

    Uses Gemini 1.5 Pro Vision for image understanding.
    """
    try:
        lesson_data = await gemini_service.analyze_image(
            image_base64=request.image_base64,
            profile=request.user_profile.value,
        )

        modules = [
            LessonModule(**mod) for mod in lesson_data.get("modules", [])
        ]

        return LessonResponse(
            title=lesson_data.get("title", "Image Analysis"),
            summary=lesson_data.get("summary", ""),
            modules=modules,
            tts_text=lesson_data.get("tts_text"),
            profile_used=request.user_profile,
            module_count=len(modules),
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Image analysis failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze image: {str(e)}"
        )
