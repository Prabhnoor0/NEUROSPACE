"""
NeuroSpace — Imagen Service
==============================
Handles image generation via Google Gemini Imagen API (google-generativeai).
Generates educational illustrations and uploads to Cloudinary for persistent URLs.
"""

import os
import base64
import logging
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


# ============================================
# Profile → Image Style Mapping
# ============================================

PROFILE_IMAGE_STYLES = {
    "ADHD": {
        "style_prefix": "Colorful, vibrant, cartoon-style",
        "suffix": "with bold outlines and engaging visual elements",
    },
    "Dyslexia": {
        "style_prefix": "Simple, high-contrast, minimalist",
        "suffix": "with very little text, clear shapes, and pastel backgrounds",
    },
    "Autism": {
        "style_prefix": "Clean, structured, labeled diagram style",
        "suffix": "with clear hierarchy, muted colors, and precise labels",
    },
}


# ============================================
# Image Generation via Gemini + Cloudinary Upload
# ============================================

async def generate_image(
    description: str,
    profile: Optional[str] = None,
) -> dict:
    """
    Generate an educational illustration using Google Gemini's image generation.
    Uploads to Cloudinary for persistent URL access.

    Args:
        description: What the image should depict
        profile: Neuro-profile for style adaptation

    Returns:
        Dict with 'image_base64', 'mime_type', and 'image_url' (Cloudinary)
    """
    try:
        import google.generativeai as genai
        from .llm_core import get_gemini_model

        # Ensure Gemini is configured
        get_gemini_model()

        # Build the full prompt with profile-specific style
        style_config = PROFILE_IMAGE_STYLES.get(profile, PROFILE_IMAGE_STYLES["ADHD"])
        full_prompt = (
            f"{style_config['style_prefix']} educational illustration of: {description}. "
            f"{style_config['suffix']}. "
            "Flat design, suitable for a learning app. No text in the image."
        )

        # Use Gemini's imagen model for image generation
        imagen_model = genai.ImageGenerationModel("imagen-3.0-generate-002")

        response = imagen_model.generate_images(
            prompt=full_prompt,
            number_of_images=1,
            aspect_ratio="16:9",
            safety_filter_level="block_only_high",
        )

        if response.images:
            image = response.images[0]
            image_bytes = image._image_bytes
            image_b64 = base64.b64encode(image_bytes).decode("utf-8")

            logger.info(f"Imagen generated: {len(image_bytes)} bytes for '{description[:50]}...'")

            # Upload to Cloudinary for persistent URL
            image_url = None
            try:
                from . import cloudinary_service
                if cloudinary_service.is_configured():
                    image_url = cloudinary_service.upload_image(image_bytes)
            except Exception as e:
                logger.warning(f"Cloudinary image upload failed: {e}")

            return {
                "image_base64": image_b64,
                "mime_type": "image/png",
                "image_url": image_url,
            }
        else:
            logger.warning("Imagen returned no images")
            return {"image_base64": None, "mime_type": None, "image_url": None}

    except Exception as e:
        logger.error(f"Image generation failed: {e}")
        # Return None rather than crashing — images are optional
        return {"image_base64": None, "mime_type": None, "image_url": None}
