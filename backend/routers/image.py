"""
NeuroSpace — Image Generation Router
=======================================
Handles on-demand image generation via Vertex AI Imagen.
Used when lessons need custom educational illustrations.
"""

import logging
import base64
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional
import io

from services import imagen_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Request Model
# ============================================

class ImageGenerateRequest(BaseModel):
    description: str = Field(
        ...,
        description="What the educational illustration should depict",
        min_length=5,
    )
    profile: Optional[str] = Field(
        default="ADHD",
        description="Neuro-profile for style adaptation",
    )


# ============================================
# Generate Image
# ============================================

@router.post("/generate-image")
async def generate_image(request: ImageGenerateRequest):
    """
    Generate an educational illustration using Vertex AI Imagen 3.

    Profile-aware styling:
    - ADHD: Colorful, vibrant, cartoon-style
    - Dyslexia: Simple, high-contrast, minimalist
    - Autism: Clean, structured, labeled diagrams

    Returns the image as a JSON response with base64-encoded data.
    """
    try:
        result = await imagen_service.generate_image(
            description=request.description,
            profile=request.profile,
        )

        if result.get("image_base64"):
            return {
                "status": "success",
                "image_base64": result["image_base64"],
                "mime_type": result["mime_type"],
            }
        else:
            return {
                "status": "no_image",
                "message": "Image generation returned no results. Try a different description.",
                "image_base64": None,
                "mime_type": None,
            }

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Image generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate image: {str(e)}"
        )


# ============================================
# Generate Image as File (returns PNG directly)
# ============================================

@router.post("/generate-image/file")
async def generate_image_file(request: ImageGenerateRequest):
    """
    Generate an educational illustration and return it as a PNG file.
    Useful for direct embedding in Flutter Image widgets.
    """
    try:
        result = await imagen_service.generate_image(
            description=request.description,
            profile=request.profile,
        )

        if result.get("image_base64"):
            image_bytes = base64.b64decode(result["image_base64"])
            image_stream = io.BytesIO(image_bytes)

            return StreamingResponse(
                image_stream,
                media_type="image/png",
                headers={
                    "Content-Disposition": "inline; filename=neurospace_illustration.png",
                    "Content-Length": str(len(image_bytes)),
                },
            )
        else:
            raise HTTPException(
                status_code=404,
                detail="No image generated. Try a different description.",
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Image file generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate image: {str(e)}"
        )
