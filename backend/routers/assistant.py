"""
NeuroSpace — Assistant Router
==============================
Unified assistant command endpoint for overlay clients.
Provides simplify, summarize, easy-read, and TTS-text actions.
"""

import logging
from fastapi import APIRouter, HTTPException

from models.schemas import (
    SimplifyRequest,
    SimplifyResponse,
    SummaryResponse,
    EasyReadRequest,
    EasyReadResponse,
)
from routers.simplify import simplify_text, summarize_text
from services import gemini_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Simplify — rewrites text in simpler language
# ============================================

@router.post("/assistant/simplify", response_model=SimplifyResponse)
async def assistant_simplify(request: SimplifyRequest):
    """Assistant simplify: rewrites text in simpler, accessible language."""
    return await simplify_text(request)


# ============================================
# Summarize — structured summary with key points
# ============================================

@router.post("/assistant/summarize", response_model=SummaryResponse)
async def assistant_summarize(request: SimplifyRequest):
    """Assistant summarize: returns structured summary with key points, tone, etc."""
    return await summarize_text(request)


# ============================================
# Easy Read — AI-formatted accessible content
# ============================================

@router.post("/assistant/easy-read", response_model=EasyReadResponse)
async def assistant_easy_read(request: EasyReadRequest):
    """
    AI-powered Easy Read: reformats text into highly accessible,
    well-structured content with clear sections, bullet points,
    bold keywords, and simple language.
    """
    try:
        result = await gemini_service.easy_read_text(
            text=request.text,
            profile=request.user_profile.value,
        )
        return EasyReadResponse(**result)
    except Exception as e:
        logger.error(f"Easy Read failed: {e}", exc_info=True)
        # Graceful local fallback
        return _local_easy_read_fallback(request.text)


def _local_easy_read_fallback(text: str) -> EasyReadResponse:
    """Generate a basic local easy-read version when AI is unavailable."""
    import re
    cleaned = " ".join(text.split())
    sentences = re.split(r'(?<=[.!?])\s+', cleaned)
    sentences = [s.strip() for s in sentences if s.strip()]

    sections = []
    current_section = {"heading": "Main Content", "bullets": []}

    for s in sentences:
        if len(s) > 100:
            # Break long sentences at commas
            parts = [p.strip() for p in s.split(",") if p.strip()]
            current_section["bullets"].extend(parts)
        else:
            current_section["bullets"].append(s)

        if len(current_section["bullets"]) >= 5:
            sections.append(current_section)
            current_section = {"heading": "More Details", "bullets": []}

    if current_section["bullets"]:
        sections.append(current_section)

    if not sections:
        sections = [{"heading": "Content", "bullets": [cleaned[:300] or "No content available."]}]

    formatted_parts = []
    for sec in sections:
        formatted_parts.append(f"📌 {sec['heading']}")
        for b in sec["bullets"]:
            formatted_parts.append(f"  • {b}")
        formatted_parts.append("")

    return EasyReadResponse(
        formatted_text="\n".join(formatted_parts).strip(),
        sections=sections,
        word_count=len(cleaned.split()),
        reading_level="simplified",
        estimated_read_time=f"{max(1, len(cleaned.split()) // 150)} min read",
    )
