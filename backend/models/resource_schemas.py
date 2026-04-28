"""
NeuroSpace — Resource Allocation Assistant Schemas
===================================================
Pydantic models for recommendation, booking lifecycle,
session summaries, timeline events, NGO discovery, and help requests.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from enum import Enum
from datetime import datetime


# ============================================
# Enums
# ============================================

class ResourceCategory(str, Enum):
    EDUCATION = "education"
    MEDICAL = "medical"


class ResourceType(str, Enum):
    SPECIAL_EDUCATOR = "special_educator"
    SPEECH_THERAPY = "speech_therapy"
    OCCUPATIONAL_THERAPY = "occupational_therapy"
    REMEDIAL_LEARNING = "remedial_learning"
    SIMPLIFIED_MODULE = "simplified_module"
    NEUROLOGIST = "neurologist"
    PSYCHOLOGIST = "psychologist"
    REHAB_CENTER = "rehab_center"
    SUPPORT_GROUP = "support_group"
    HOSPITAL = "hospital"
    NGO = "ngo"


class BookingStatus(str, Enum):
    PENDING = "pending"
    NOT_CONFIRMED = "not_confirmed"
    CONFIRMED = "confirmed"
    RESCHEDULED = "rescheduled"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class UrgencyLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class DeliveryMode(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    BOTH = "both"


class SessionMode(str, Enum):
    ONLINE = "online"
    IN_PERSON = "in_person"
    PHONE = "phone"
    HOME_VISIT = "home_visit"


# ============================================
# Timeline Event (status change history)
# ============================================

class TimelineEvent(BaseModel):
    timestamp: str
    status: str
    title: str
    description: Optional[str] = None
    actor: str = "system"  # "user", "provider", "system"


# ============================================
# Session Summary
# ============================================

class SessionSummary(BaseModel):
    title: Optional[str] = None
    short_summary: Optional[str] = None
    full_summary: Optional[str] = None
    status_note: Optional[str] = None
    provider_remarks: Optional[str] = None
    user_feedback: Optional[str] = None
    support_given: Optional[str] = None
    next_steps: Optional[str] = None
    follow_up_date: Optional[str] = None
    session_outcome: Optional[str] = None
    resource_recommendation: Optional[str] = None
    attendance: Optional[str] = None  # "attended", "no_show", "partial"


# ============================================
# Recommendation Request / Response
# ============================================

class RecommendationRequest(BaseModel):
    diagnosis: Optional[str] = Field(None, description="e.g. ADHD, Dyslexia, Autism")
    difficulty_level: Optional[str] = Field(None, description="e.g. mild, moderate, severe")
    urgency: UrgencyLevel = Field(default=UrgencyLevel.MEDIUM)
    age_group: Optional[str] = Field(None, description="e.g. child, teen, adult")
    language: Optional[str] = Field(default="English")
    budget: Optional[str] = Field(None, description="e.g. free, low, medium, high")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_radius_km: float = Field(default=25.0, ge=1.0, le=200.0)
    delivery_mode: DeliveryMode = Field(default=DeliveryMode.BOTH)
    category: ResourceCategory = Field(default=ResourceCategory.EDUCATION)
    sensory_needs: Optional[str] = Field(None, description="e.g. low-noise, dim-light")
    accessibility_needs: Optional[str] = Field(None, description="e.g. wheelchair, elevator")


class RecommendedResource(BaseModel):
    id: str
    name: str
    type: ResourceType
    category: ResourceCategory
    distance_km: Optional[float] = None
    availability: str = "Available"
    price_range: Optional[str] = None
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    contact: Optional[str] = None
    email: Optional[str] = None
    accessibility_notes: Optional[str] = None
    score: float = Field(ge=0.0, le=100.0)
    reason: str
    booking_available: bool = True
    languages: List[str] = ["English"]
    timings: Optional[str] = None
    services: List[str] = []


class RecommendationResponse(BaseModel):
    recommendations: List[RecommendedResource]
    total: int
    query_summary: str
    fallback_used: bool = False


# ============================================
# Booking (full lifecycle)
# ============================================

class BookingRequest(BaseModel):
    user_id: str
    resource_id: str
    resource_name: str
    resource_type: str  # Using str for flexibility
    category: str
    date: str = Field(..., description="ISO date string YYYY-MM-DD")
    time: str = Field(..., description="HH:MM format")
    mode: SessionMode = SessionMode.IN_PERSON
    location: Optional[str] = None
    notes: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    provider_name: Optional[str] = None


class BookingResponse(BaseModel):
    booking_id: str
    user_id: str
    resource_id: str
    resource_name: str
    resource_type: str
    category: str
    title: str
    description: Optional[str] = None
    provider_name: Optional[str] = None
    date: str
    time: str
    mode: str = "in_person"
    location: Optional[str] = None
    notes: Optional[str] = None
    status: BookingStatus = BookingStatus.PENDING
    created_at: str
    updated_at: str
    summary: Optional[SessionSummary] = None
    timeline: List[TimelineEvent] = []


class BookingUpdateRequest(BaseModel):
    status: Optional[BookingStatus] = None
    date: Optional[str] = None
    time: Optional[str] = None
    notes: Optional[str] = None
    mode: Optional[SessionMode] = None
    location: Optional[str] = None


class SummaryUpdateRequest(BaseModel):
    title: Optional[str] = None
    short_summary: Optional[str] = None
    full_summary: Optional[str] = None
    status_note: Optional[str] = None
    provider_remarks: Optional[str] = None
    user_feedback: Optional[str] = None
    support_given: Optional[str] = None
    next_steps: Optional[str] = None
    follow_up_date: Optional[str] = None
    session_outcome: Optional[str] = None
    resource_recommendation: Optional[str] = None
    attendance: Optional[str] = None


class NoteAddRequest(BaseModel):
    note: str = Field(..., min_length=1, max_length=2000)
    author: str = "user"


class RescheduleRequest(BaseModel):
    new_date: str
    new_time: str
    reason: Optional[str] = None


# ============================================
# Dashboard Stats
# ============================================

class DashboardStats(BaseModel):
    total_bookings: int = 0
    pending: int = 0
    confirmed: int = 0
    in_progress: int = 0
    completed: int = 0
    cancelled: int = 0
    rescheduled: int = 0
    not_confirmed: int = 0
    upcoming_count: int = 0
    next_session: Optional[BookingResponse] = None
    recent_activity: List[TimelineEvent] = []


# ============================================
# Session History
# ============================================

class SessionEntry(BaseModel):
    booking_id: str
    resource_name: str
    resource_type: str
    category: str
    title: str
    provider_name: Optional[str] = None
    date: str
    time: str
    mode: str = "in_person"
    location: Optional[str] = None
    notes: Optional[str] = None
    status: str
    created_at: str
    updated_at: str
    short_summary: Optional[str] = None
    timeline_count: int = 0


class SessionHistoryResponse(BaseModel):
    upcoming: List[SessionEntry]
    pending: List[SessionEntry]
    confirmed: List[SessionEntry]
    completed: List[SessionEntry]
    cancelled: List[SessionEntry]
    rescheduled: List[SessionEntry]
    all_sessions: List[SessionEntry]


# ============================================
# NGO
# ============================================

class NGOEntry(BaseModel):
    id: str
    name: str
    distance_km: Optional[float] = None
    services: List[str]
    contact: Optional[str] = None
    whatsapp: Optional[str] = None
    email: Optional[str] = None
    languages: List[str] = ["English"]
    timings: Optional[str] = None
    area_served: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class NGOListResponse(BaseModel):
    ngos: List[NGOEntry]
    total: int


# ============================================
# Help Request
# ============================================

class HelpRequestCreate(BaseModel):
    user_id: str
    ngo_id: str
    ngo_name: str
    message: str = Field(..., min_length=1, max_length=1000)
    contact_preference: Optional[str] = Field(
        default="any",
        description="call, whatsapp, email, any"
    )


class HelpRequestResponse(BaseModel):
    request_id: str
    user_id: str
    ngo_id: str
    ngo_name: str
    message: str
    contact_preference: str
    status: str = "sent"
    created_at: str
