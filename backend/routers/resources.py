"""
NeuroSpace — Resource Allocation Assistant Router
===================================================
Full lifecycle API: recommendations, booking CRUD, status transitions,
session summaries, timeline events, dashboard stats, NGOs, help requests.
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
    SessionMode,
    SessionSummary,
    TimelineEvent,
    SummaryUpdateRequest,
    NoteAddRequest,
    RescheduleRequest,
    DashboardStats,
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
_bookings: dict = {}
_help_requests: dict = {}

# ============================================
# Helper: auto-generate summary text for status
# ============================================
_STATUS_DESCRIPTIONS = {
    BookingStatus.PENDING: "Your booking has been submitted and is awaiting confirmation from the provider.",
    BookingStatus.NOT_CONFIRMED: "The provider has not yet confirmed this booking. Please follow up or try another provider.",
    BookingStatus.CONFIRMED: "Your session has been confirmed by the provider. Please arrive on time.",
    BookingStatus.RESCHEDULED: "This session has been rescheduled. Please check the updated date and time.",
    BookingStatus.IN_PROGRESS: "Your session is currently in progress.",
    BookingStatus.COMPLETED: "This session has been completed. Check the summary for details and next steps.",
    BookingStatus.CANCELLED: "This booking has been cancelled.",
}


def _add_timeline_event(booking_data: dict, status: str, title: str,
                        description: str = None, actor: str = "system"):
    """Append a timeline event to a booking's timeline list."""
    event = {
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "title": title,
        "description": description or _STATUS_DESCRIPTIONS.get(status, ""),
        "actor": actor,
    }
    if "timeline" not in booking_data:
        booking_data["timeline"] = []
    booking_data["timeline"].append(event)


def _update_summary_field(booking_data: dict, **kwargs):
    """Update specific fields on the booking's summary dict."""
    if "summary" not in booking_data or booking_data["summary"] is None:
        booking_data["summary"] = {}
    for k, v in kwargs.items():
        if v is not None:
            booking_data["summary"][k] = v


def _booking_to_response(booking_data: dict) -> BookingResponse:
    """Convert raw dict to BookingResponse, handling nested models."""
    summary_data = booking_data.get("summary")
    summary = SessionSummary(**summary_data) if summary_data else None
    timeline_data = booking_data.get("timeline", [])
    timeline = [TimelineEvent(**e) for e in timeline_data]
    return BookingResponse(
        booking_id=booking_data["booking_id"],
        user_id=booking_data["user_id"],
        resource_id=booking_data["resource_id"],
        resource_name=booking_data["resource_name"],
        resource_type=booking_data["resource_type"],
        category=booking_data["category"],
        title=booking_data.get("title", booking_data["resource_name"]),
        description=booking_data.get("description"),
        provider_name=booking_data.get("provider_name"),
        date=booking_data["date"],
        time=booking_data["time"],
        mode=booking_data.get("mode", "in_person"),
        location=booking_data.get("location"),
        notes=booking_data.get("notes"),
        status=booking_data["status"],
        created_at=booking_data["created_at"],
        updated_at=booking_data.get("updated_at", booking_data["created_at"]),
        summary=summary,
        timeline=timeline,
    )


# ============================================
# Recommendations
# ============================================

@router.post("/resources/recommend", response_model=RecommendationResponse)
async def recommend_resources(request: RecommendationRequest):
    """Get AI-scored resource recommendations based on user profile."""
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
# Booking CRUD
# ============================================

@router.post("/resources/book", response_model=BookingResponse)
async def create_booking(request: BookingRequest):
    """Create a new booking with initial pending status and timeline."""
    booking_id = f"bk_{uuid4().hex[:10]}"
    now = datetime.now().isoformat()

    title = request.title or f"{request.resource_name} Session"

    booking_data = {
        "booking_id": booking_id,
        "user_id": request.user_id,
        "resource_id": request.resource_id,
        "resource_name": request.resource_name,
        "resource_type": request.resource_type,
        "category": request.category,
        "title": title,
        "description": request.description or f"Session with {request.resource_name}",
        "provider_name": request.provider_name or request.resource_name,
        "date": request.date,
        "time": request.time,
        "mode": request.mode.value if hasattr(request.mode, 'value') else request.mode,
        "location": request.location,
        "notes": request.notes,
        "status": BookingStatus.PENDING.value,
        "created_at": now,
        "updated_at": now,
        "summary": {
            "title": title,
            "short_summary": f"Booking submitted for {request.resource_name} on {request.date} at {request.time}.",
            "status_note": _STATUS_DESCRIPTIONS[BookingStatus.PENDING],
        },
        "timeline": [],
    }

    _add_timeline_event(
        booking_data,
        BookingStatus.PENDING.value,
        "Booking Created",
        f"Session booked with {request.resource_name} for {request.date} at {request.time}.",
        actor="user",
    )

    _bookings[booking_id] = booking_data
    logger.info(f"[Booking] Created {booking_id} for user {request.user_id}")
    return _booking_to_response(booking_data)


@router.get("/resources/booking/{booking_id}", response_model=BookingResponse)
async def get_booking(booking_id: str):
    """Get a specific booking by ID with full summary and timeline."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    return _booking_to_response(_bookings[booking_id])


@router.get("/resources/bookings/{user_id}")
async def list_user_bookings(user_id: str):
    """Get all bookings for a user, sorted newest first."""
    user_bookings = []
    for bk_data in _bookings.values():
        if bk_data.get("user_id") == user_id:
            user_bookings.append(_booking_to_response(bk_data).model_dump())
    # Sort by created_at descending
    user_bookings.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return {"bookings": user_bookings, "total": len(user_bookings)}


@router.patch("/resources/booking/{booking_id}", response_model=BookingResponse)
async def update_booking(booking_id: str, update: BookingUpdateRequest):
    """Update a booking's status, date, time, notes, mode, or location."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")

    bk = _bookings[booking_id]
    now = datetime.now().isoformat()
    bk["updated_at"] = now

    if update.status is not None:
        old_status = bk["status"]
        bk["status"] = update.status.value
        _add_timeline_event(
            bk, update.status.value,
            f"Status → {update.status.value.replace('_', ' ').title()}",
            _STATUS_DESCRIPTIONS.get(update.status, ""),
        )
        _update_summary_field(bk, status_note=_STATUS_DESCRIPTIONS.get(update.status, ""))

    if update.date is not None:
        bk["date"] = update.date
    if update.time is not None:
        bk["time"] = update.time
    if update.notes is not None:
        bk["notes"] = update.notes
    if update.mode is not None:
        bk["mode"] = update.mode.value
    if update.location is not None:
        bk["location"] = update.location

    logger.info(f"[Booking] Updated {booking_id}")
    return _booking_to_response(bk)


# ============================================
# Status Transition Shortcuts
# ============================================

@router.post("/resources/booking/{booking_id}/confirm", response_model=BookingResponse)
async def confirm_booking(booking_id: str):
    """Mark a booking as confirmed."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["status"] = BookingStatus.CONFIRMED.value
    bk["updated_at"] = datetime.now().isoformat()
    _add_timeline_event(bk, BookingStatus.CONFIRMED.value, "Booking Confirmed",
                        "The provider has confirmed your session.", actor="provider")
    _update_summary_field(bk,
                          status_note=_STATUS_DESCRIPTIONS[BookingStatus.CONFIRMED],
                          short_summary=f"Confirmed: {bk['resource_name']} on {bk['date']} at {bk['time']}.")
    return _booking_to_response(bk)


@router.post("/resources/booking/{booking_id}/start", response_model=BookingResponse)
async def start_session(booking_id: str):
    """Mark a booking as in-progress."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["status"] = BookingStatus.IN_PROGRESS.value
    bk["updated_at"] = datetime.now().isoformat()
    _add_timeline_event(bk, BookingStatus.IN_PROGRESS.value, "Session Started",
                        "Your session is now in progress.", actor="system")
    _update_summary_field(bk, status_note=_STATUS_DESCRIPTIONS[BookingStatus.IN_PROGRESS])
    return _booking_to_response(bk)


@router.post("/resources/booking/{booking_id}/complete", response_model=BookingResponse)
async def complete_session(booking_id: str):
    """Mark a booking as completed and generate completion summary."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["status"] = BookingStatus.COMPLETED.value
    bk["updated_at"] = datetime.now().isoformat()
    _add_timeline_event(bk, BookingStatus.COMPLETED.value, "Session Completed",
                        "Your session has been completed successfully.", actor="system")
    _update_summary_field(
        bk,
        status_note=_STATUS_DESCRIPTIONS[BookingStatus.COMPLETED],
        short_summary=f"Completed: {bk['resource_name']} session on {bk['date']}.",
        session_outcome="Session completed successfully. Review notes for details.",
        attendance="attended",
    )
    return _booking_to_response(bk)


@router.post("/resources/booking/{booking_id}/cancel", response_model=BookingResponse)
async def cancel_booking(booking_id: str, reason: Optional[str] = Query(None)):
    """Cancel a booking."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["status"] = BookingStatus.CANCELLED.value
    bk["updated_at"] = datetime.now().isoformat()
    desc = reason or "Booking cancelled by user."
    _add_timeline_event(bk, BookingStatus.CANCELLED.value, "Booking Cancelled", desc, actor="user")
    _update_summary_field(bk, status_note=desc,
                          short_summary=f"Cancelled: {bk['resource_name']} on {bk['date']}.")
    return _booking_to_response(bk)


@router.post("/resources/booking/{booking_id}/reschedule", response_model=BookingResponse)
async def reschedule_booking(booking_id: str, req: RescheduleRequest):
    """Reschedule a booking to new date/time."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    old_date, old_time = bk["date"], bk["time"]
    bk["date"] = req.new_date
    bk["time"] = req.new_time
    bk["status"] = BookingStatus.RESCHEDULED.value
    bk["updated_at"] = datetime.now().isoformat()
    desc = req.reason or f"Rescheduled from {old_date} {old_time} to {req.new_date} {req.new_time}."
    _add_timeline_event(bk, BookingStatus.RESCHEDULED.value, "Session Rescheduled", desc, actor="user")
    _update_summary_field(bk, status_note=desc,
                          short_summary=f"Rescheduled: {bk['resource_name']} to {req.new_date} at {req.new_time}.")
    return _booking_to_response(bk)


# ============================================
# Summary & Notes
# ============================================

@router.patch("/resources/booking/{booking_id}/summary", response_model=BookingResponse)
async def update_summary(booking_id: str, req: SummaryUpdateRequest):
    """Update the session summary fields."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["updated_at"] = datetime.now().isoformat()
    update_fields = {k: v for k, v in req.model_dump().items() if v is not None}
    _update_summary_field(bk, **update_fields)
    _add_timeline_event(bk, bk["status"], "Summary Updated",
                        "Session summary has been updated.", actor="provider")
    return _booking_to_response(bk)


@router.post("/resources/booking/{booking_id}/note", response_model=BookingResponse)
async def add_note(booking_id: str, req: NoteAddRequest):
    """Add a note to a booking (appends to existing notes)."""
    if booking_id not in _bookings:
        raise HTTPException(status_code=404, detail="Booking not found")
    bk = _bookings[booking_id]
    bk["updated_at"] = datetime.now().isoformat()
    existing = bk.get("notes") or ""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    new_note = f"[{timestamp} | {req.author}] {req.note}"
    bk["notes"] = f"{existing}\n{new_note}".strip() if existing else new_note
    _add_timeline_event(bk, bk["status"], "Note Added",
                        f"Note by {req.author}: {req.note[:80]}...", actor=req.author)
    return _booking_to_response(bk)


# ============================================
# Dashboard Stats
# ============================================

@router.get("/resources/dashboard/{user_id}", response_model=DashboardStats)
async def get_dashboard_stats(user_id: str):
    """Get dashboard summary stats for a user."""
    now = datetime.now()
    stats = {
        "total_bookings": 0, "pending": 0, "confirmed": 0,
        "in_progress": 0, "completed": 0, "cancelled": 0,
        "rescheduled": 0, "not_confirmed": 0, "upcoming_count": 0,
    }
    next_session = None
    next_date = None
    recent_events = []

    for bk_data in _bookings.values():
        if bk_data.get("user_id") != user_id:
            continue
        stats["total_bookings"] += 1
        status = bk_data.get("status", "pending")
        if status in stats:
            stats[status] += 1

        # Check upcoming
        try:
            bk_date = datetime.fromisoformat(bk_data["date"])
            if bk_date.date() >= now.date() and status not in ("cancelled", "completed"):
                stats["upcoming_count"] += 1
                if next_date is None or bk_date < next_date:
                    next_date = bk_date
                    next_session = _booking_to_response(bk_data)
        except (ValueError, TypeError):
            pass

        # Collect recent timeline events
        for evt in bk_data.get("timeline", [])[-3:]:
            evt_copy = dict(evt)
            evt_copy["_booking_id"] = bk_data["booking_id"]
            recent_events.append(evt_copy)

    # Sort events by timestamp descending, take last 10
    recent_events.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    recent_timeline = [
        TimelineEvent(
            timestamp=e["timestamp"],
            status=e["status"],
            title=e["title"],
            description=e.get("description"),
            actor=e.get("actor", "system"),
        )
        for e in recent_events[:10]
    ]

    return DashboardStats(
        **stats,
        next_session=next_session,
        recent_activity=recent_timeline,
    )


# ============================================
# Session History
# ============================================

@router.get("/resources/sessions/{user_id}", response_model=SessionHistoryResponse)
async def get_session_history(user_id: str):
    """Get categorized session history for a user."""
    now = datetime.now()
    groups = {
        "upcoming": [], "pending": [], "confirmed": [],
        "completed": [], "cancelled": [], "rescheduled": [],
    }
    all_sessions = []

    for bk_data in _bookings.values():
        if bk_data.get("user_id") != user_id:
            continue

        summary = bk_data.get("summary") or {}
        entry = SessionEntry(
            booking_id=bk_data["booking_id"],
            resource_name=bk_data["resource_name"],
            resource_type=bk_data["resource_type"],
            category=bk_data["category"],
            title=bk_data.get("title", bk_data["resource_name"]),
            provider_name=bk_data.get("provider_name"),
            date=bk_data["date"],
            time=bk_data["time"],
            mode=bk_data.get("mode", "in_person"),
            location=bk_data.get("location"),
            notes=bk_data.get("notes"),
            status=bk_data["status"],
            created_at=bk_data["created_at"],
            updated_at=bk_data.get("updated_at", bk_data["created_at"]),
            short_summary=summary.get("short_summary"),
            timeline_count=len(bk_data.get("timeline", [])),
        )

        all_sessions.append(entry)
        status = bk_data["status"]

        if status == "cancelled":
            groups["cancelled"].append(entry)
        elif status == "completed":
            groups["completed"].append(entry)
        elif status == "rescheduled":
            groups["rescheduled"].append(entry)
        elif status == "confirmed":
            groups["confirmed"].append(entry)
        elif status == "pending" or status == "not_confirmed":
            groups["pending"].append(entry)
        elif status == "in_progress":
            groups["upcoming"].append(entry)
        else:
            # Default: check date
            try:
                bk_date = datetime.fromisoformat(bk_data["date"])
                if bk_date.date() >= now.date():
                    groups["upcoming"].append(entry)
                else:
                    groups["completed"].append(entry)
            except (ValueError, TypeError):
                groups["upcoming"].append(entry)

    # Sort all by date descending
    all_sessions.sort(key=lambda x: x.created_at, reverse=True)

    return SessionHistoryResponse(
        upcoming=groups["upcoming"],
        pending=groups["pending"],
        confirmed=groups["confirmed"],
        completed=groups["completed"],
        cancelled=groups["cancelled"],
        rescheduled=groups["rescheduled"],
        all_sessions=all_sessions,
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
