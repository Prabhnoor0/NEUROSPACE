"""
NeuroSpace — Lessons Router
==============================
Handles lesson generation, deep-dive expansion, and lesson management.
"""

import logging
from fastapi import APIRouter, HTTPException

from models.schemas import (
    LessonRequest,
    LessonResponse,
    LessonModule,
    DeepDiveRequest,
)
from services import gemini_service, imagen_service, tts_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Generate Lesson
# ============================================

@router.post("/generate-lesson", response_model=LessonResponse)
async def generate_lesson(request: LessonRequest):
    """
    Generate an adaptive lesson based on the user's topic and neuro-profile.

    This is the main endpoint that chains:
    1. Gemini 1.5 Flash + Search Grounding → structured lesson JSON
    2. Vertex AI Imagen (optional) → educational illustrations
    3. Cloud TTS (optional) → audio narration URL

    The response contains lesson modules that Flutter renders dynamically.
    """
    try:
        # Step 1: Generate the lesson via Gemini
        lesson_data = await gemini_service.generate_lesson(
            topic=request.topic,
            profile=request.user_profile.value,
            energy_level=request.energy_level.value,
            visuals_needed=request.visuals_needed,
        )

        # Step 2: Process image_prompt modules → generate actual images
        if request.visuals_needed and "modules" in lesson_data:
            for module in lesson_data["modules"]:
                if module.get("type") == "image_prompt":
                    try:
                        image_result = await imagen_service.generate_image(
                            description=module.get("description", "educational illustration"),
                            profile=request.user_profile.value,
                        )
                        # Convert image_prompt to image module
                        module["type"] = "image"
                        module["image_base64"] = image_result.get("image_base64")
                        module["alt_text"] = module.pop("description", "")
                        module["caption"] = f"AI-generated illustration"
                    except Exception as e:
                        logger.warning(f"Image generation skipped: {e}")
                        # Remove failed image module
                        module["type"] = "text_block"
                        module["content"] = f"📷 *Visual: {module.get('description', '')}*"
                        module["section_type"] = "explanation"

        # Step 3: Generate TTS audio (optional, async in production)
        audio_url = None
        tts_text = lesson_data.get("tts_text")
        # TTS generation can be done on-demand via the /text-to-speech endpoint
        # to avoid slowing down the initial lesson response

        # Build response
        modules = [
            LessonModule(**mod) for mod in lesson_data.get("modules", [])
        ]

        return LessonResponse(
            title=lesson_data.get("title", f"Lesson: {request.topic}"),
            summary=lesson_data.get("summary", ""),
            modules=modules,
            tts_text=tts_text,
            audio_url=audio_url,
            profile_used=request.user_profile,
            module_count=len(modules),
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Lesson generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate lesson: {str(e)}"
        )


# ============================================
# Deep Dive (expand sub-topic)
# ============================================

@router.post("/deep-dive", response_model=LessonResponse)
async def deep_dive(request: DeepDiveRequest):
    """
    Generate a deep-dive sub-lesson for a specific sub-topic.
    Used when users (especially Autism profile) tap "Expand" on a deep_dive module.
    Supports infinite nesting for hyper-fixation.
    """
    try:
        lesson_data = await gemini_service.generate_deep_dive(
            parent_topic=request.parent_topic,
            sub_topic=request.sub_topic,
            profile=request.user_profile.value,
        )

        modules = [
            LessonModule(**mod) for mod in lesson_data.get("modules", [])
        ]

        return LessonResponse(
            title=lesson_data.get("title", f"Deep Dive: {request.sub_topic}"),
            summary=lesson_data.get("summary", ""),
            modules=modules,
            tts_text=lesson_data.get("tts_text"),
            profile_used=request.user_profile,
            module_count=len(modules),
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Deep dive generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate deep dive: {str(e)}"
        )
