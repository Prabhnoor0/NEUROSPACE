from fastapi import APIRouter, Query, HTTPException
from typing import List, Dict, Any
from services.maps_service import get_quiet_spaces
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/quiet-spaces", response_model=List[Dict[str, Any]])
async def fetch_quiet_spaces(
    lat: float = Query(..., description="Latitude of the user"),
    lng: float = Query(..., description="Longitude of the user"),
    radius: int = Query(3000, description="Search radius in meters")
):
    """
    Fetch sensory-friendly 'Quiet Spaces' curated by Groq based on real location data.
    """
    try:
        places = await get_quiet_spaces(lat, lng, radius)
        return places
    except Exception as e:
        logger.error(f"Error fetching quiet spaces: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch quiet spaces")
