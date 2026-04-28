"""
NeuroSpace — Resource Allocation Assistant Router
===================================================
API endpoints for resource recommendations, booking,
session history, NGO discovery, and help requests.
"""

import logging
from datetime import datetime
from uuid import uuid4
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from models.resource_schemas import (
    RecommendationRequest,
    RecommendationResponse,
    BookingRequest,
    BookingResponse,
    BookingUpdateRequest,
    BookingStatus,
    SessionHistoryResponse,
    SessionEntry,
    NGOListResponse,
    HelpRequestCreate,
    HelpRequestResponse,
)
from services.resource_engine import get_recommendations, get_nearby_ngos

logger = logging.getLogger(__name__)

router = APIRouter()

# ============================================
# In-memory stores (persisted to Firebase via Flutter)
# ============================================
# These are thin server-side caches for the current session.
# Real persistence happens in Firebase via the Flutter client.
_bookings: dict = {}
_help_requests: dict = {}


# ============================================
# Recommendations
# ============================================

@router.post("/resources/recommend", response_model=RecommendationResponse)
async def recommend_resources(request: RecommendationRequest):
    """
    Get AI-scored resource recommendations based on user profile.
    Falls back to curated data if APIs are unavailable.
    """
    try:
        result = await get_recommendations(request)
        logger.info(
            f"[Resources] Returned {result.total} recommendations "
            f"(fallback={result.fallback_used})"
        )
        return result
    except Exception as e:
        logger.error(f"[Resources] Recommendation error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Recommendation failed: {str(e)}")


# ============================================
# Booking
# ============================================

@router.post("/resources/book", response_model=BookingResponse)
async def create_booking(request: BookingRequest):
    """Create a new booking for a recommended resource."""
    booking_id = f"bk_{uuid4().hex[:10]}"
    now = datetime.now().isoformat()

    booking = BookingResponse(
        booking_id=booking_id,
        user_id=request.user_id,
        resource_id=request.resource_id,
        resource_name=request.resource_name,
        resource_type=request.resource_type,
        category=request.category,
        date=request.date,
        time=request.time,
        location=request.location,
        notes=request.notes,
        status=BookingStatus.PENDING,
        created_at=now,
    )

    _bookings[booking_id] = booking.model_dump()
    logger.info(f"[Booking] Created booking {booking_id} for user {request.user_id}")
    return booking


@router.patch("/resources/booking/{booking_id}", response_model=BookingResponse)
async def update_booking(booking_id: str, update: BookingUpdateRequest):
    """Update a booking's status, date, time, or notes."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")

    booking_data = _bookings[booking_id]

    if update.status is not None:
        booking_data["status"] = update.status.value
    if update.date is not None:
        booking_data["date"] = update.date
    if update.time is not None:
        booking_data["time"] = update.time
    if update.notes is not None:
        booking_data["notes"] = update.notes

    _bookings[booking_id] = booking_data
    logger.info(f"[Booking] Updated booking {booking_id}")
    return BookingResponse(**booking_data)


@router.get("/resources/booking/{booking_id}", response_model=BookingResponse)
async def get_booking(booking_id: str):
    """Get a specific booking by ID."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    return BookingResponse(**_bookings[booking_id])


# ============================================
# Session History
# ============================================

@router.get("/resources/sessions/{user_id}", response_model=SessionHistoryResponse)
async def get_session_history(user_id: str):
    """
    Get session history for a user.
    Categorizes bookings into upcoming, past, and cancelled.
    """
    now = datetime.now()
    upcoming = []
    past = []
    cancelled = []

    for bk_id, bk_data in _bookings.items():
        if bk_data.get("user_id") != user_id:
            continue

        entry = SessionEntry(
            booking_id=bk_id,
            resource_name=bk_data["resource_name"],
            resource_type=bk_data["resource_type"],
            category=bk_data["category"],
            date=bk_data["date"],
            time=bk_data["time"],
            location=bk_data.get("location"),
            notes=bk_data.get("notes"),
            status=bk_data["status"],
            created_at=bk_data["created_at"],
        )

        status = bk_data["status"]
        if status in (BookingStatus.CANCELLED.value, "cancelled"):
            cancelled.append(entry)
        elif status in (BookingStatus.COMPLETED.value, "completed"):
            past.append(entry)
        else:
            # Check date to see if it's upcoming or past
            try:
                bk_date = datetime.fromisoformat(bk_data["date"])
                if bk_date.date() >= now.date():
                    upcoming.append(entry)
                else:
                    past.append(entry)
            except (ValueError, TypeError):
                upcoming.append(entry)

    return SessionHistoryResponse(
        upcoming=upcoming,
        past=past,
        cancelled=cancelled,
    )


# ============================================
# NGO Discovery
# ============================================

@router.get("/resources/ngos", response_model=NGOListResponse)
async def discover_ngos(
    lat: float = Query(..., description="User latitude"),
    lng: float = Query(..., description="User longitude"),
    radius_km: float = Query(default=15.0, ge=1.0, le=100.0),
):
    """Discover nearby NGOs that support neurodivergent individuals."""
    try:
        result = await get_nearby_ngos(lat, lng, radius_km)
        logger.info(f"[NGOs] Returned {result.total} NGOs")
        return result
    except Exception as e:
        logger.error(f"[NGOs] Discovery error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"NGO discovery failed: {str(e)}")


# ============================================
# Help Requests
# ============================================

@router.post("/resources/help-request", response_model=HelpRequestResponse)
async def create_help_request(request: HelpRequestCreate):
    """Send a help request to an NGO."""
    request_id = f"hr_{uuid4().hex[:10]}"
    now = datetime.now().isoformat()

    help_resp = HelpRequestResponse(
        request_id=request_id,
        user_id=request.user_id,
        ngo_id=request.ngo_id,
        ngo_name=request.ngo_name,
        message=request.message,
        contact_preference=request.contact_preference or "any",
        status="sent",
        created_at=now,
    )

    _help_requests[request_id] = help_resp.model_dump()
    logger.info(f"[HelpRequest] Created {request_id} for NGO {request.ngo_name}")
    return help_resp


@router.get("/resources/help-requests/{user_id}")
async def get_help_requests(user_id: str):
    """Get all help requests for a user."""
    user_requests = [
        v for v in _help_requests.values()
        if v.get("user_id") == user_id
    ]
    return {"requests": user_requests, "total": len(user_requests)}
