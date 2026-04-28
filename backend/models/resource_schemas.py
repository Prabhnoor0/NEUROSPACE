"""
NeuroSpace — Resource Allocation Assistant Schemas
===================================================
Pydantic models for recommendation, booking, NGO discovery,
and help-request flows.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
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
    CONFIRMED = "confirmed"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    RESCHEDULED = "rescheduled"


class UrgencyLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


class DeliveryMode(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    BOTH = "both"


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
# Booking
# ============================================

class BookingRequest(BaseModel):
    user_id: str
    resource_id: str
    resource_name: str
    resource_type: ResourceType
    category: ResourceCategory
    date: str = Field(..., description="ISO date string YYYY-MM-DD")
    time: str = Field(..., description="HH:MM format")
    location: Optional[str] = None
    notes: Optional[str] = None


class BookingResponse(BaseModel):
    booking_id: str
    user_id: str
    resource_id: str
    resource_name: str
    resource_type: ResourceType
    category: ResourceCategory
    date: str
    time: str
    location: Optional[str] = None
    notes: Optional[str] = None
    status: BookingStatus = BookingStatus.PENDING
    created_at: str


class BookingUpdateRequest(BaseModel):
    status: Optional[BookingStatus] = None
    date: Optional[str] = None
    time: Optional[str] = None
    notes: Optional[str] = None


# ============================================
# Session History
# ============================================

class SessionEntry(BaseModel):
    booking_id: str
    resource_name: str
    resource_type: ResourceType
    category: ResourceCategory
    date: str
    time: str
    location: Optional[str] = None
    notes: Optional[str] = None
    status: BookingStatus
    created_at: str


class SessionHistoryResponse(BaseModel):
    upcoming: List[SessionEntry]
    past: List[SessionEntry]
    cancelled: List[SessionEntry]


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
