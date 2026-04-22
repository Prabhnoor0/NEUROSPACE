"""
NeuroSpace — Theme Generation Router
=======================================
POST /api/generate-theme — Takes user traits and returns AI-generated
theme configuration optimized for their neurodivergent needs.
"""

import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from services.theme_generator import generate_theme

logger = logging.getLogger(__name__)

router = APIRouter()


class ThemeRequest(BaseModel):
    traits: List[str]
    energy_level: Optional[str] = "medium"


@router.post("/generate-theme")
async def generate_theme_endpoint(request: ThemeRequest):
    """
    Generate an AI-powered theme configuration based on user traits.

    Traits can include:
    - lose_focus (ADHD)
    - dense_text (Dyslexia)
    - bright_lights (Sensory sensitivity)
    - literal_explanations (Autism)

    Returns a complete theme JSON with font, colors, spacing, etc.
    """
    if not request.traits:
        raise HTTPException(
            status_code=400,
            detail="At least one trait must be selected",
        )

    try:
        theme_data = await generate_theme(
            traits=request.traits,
            energy_level=request.energy_level or "medium",
        )

        return {
            "status": "success",
            "theme": theme_data,
        }

    except Exception as e:
        logger.error(f"Theme generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate theme: {str(e)}",
        )
