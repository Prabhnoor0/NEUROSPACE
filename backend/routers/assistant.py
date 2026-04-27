"""
NeuroSpace — Assistant Router
==============================
Unified assistant command endpoint for overlay clients.
"""

from fastapi import APIRouter

from models.schemas import SimplifyRequest, SimplifyResponse
from routers.simplify import simplify_text

router = APIRouter()


@router.post("/assistant/summarize", response_model=SimplifyResponse)
async def assistant_summarize(request: SimplifyRequest):
    """Assistant alias endpoint for summarize action."""
    return await simplify_text(request)


@router.post("/assistant/simplify", response_model=SimplifyResponse)
async def assistant_simplify(request: SimplifyRequest):
    """Assistant alias endpoint for simplify action."""
    return await simplify_text(request)
