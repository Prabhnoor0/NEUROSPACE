"""
NeuroSpace Backend - Pydantic Models
Defines the data schemas for API requests and responses.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum


# ============================================
# Enums
# ============================================

class NeuroProfileType(str, Enum):
    ADHD = "ADHD"
    DYSLEXIA = "Dyslexia"
    AUTISM = "Autism"
    CUSTOM = "Custom"


class EnergyLevel(str, Enum):
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


class ModuleType(str, Enum):
    TEXT_BLOCK = "text_block"
    GRAPH = "graph"
    INTERACTIVE_QUIZ = "interactive_quiz"
    IMAGE = "image"
    DEEP_DIVE = "deep_dive"
    KEY_POINT = "key_point"


class SectionType(str, Enum):
    DEFINITION = "definition"
    EXAMPLE = "example"
    EXPLANATION = "explanation"
    SUMMARY = "summary"


class ContrastMode(str, Enum):
    HIGH = "High"
    NORMAL = "Normal"
    LOW = "Low"


# ============================================
# Lesson Module Models
# ============================================

class TextBlockModule(BaseModel):
    type: str = ModuleType.TEXT_BLOCK
    content: str = Field(..., description="Markdown-formatted text content")
    section_type: Optional[SectionType] = SectionType.EXPLANATION


class GraphModule(BaseModel):
    type: str = ModuleType.GRAPH
    mermaid_code: str = Field(..., description="Valid Mermaid.js graph code")
    caption: Optional[str] = None


class QuizModule(BaseModel):
    type: str = ModuleType.INTERACTIVE_QUIZ
    question: str
    answer: str
    hint: Optional[str] = None


class ImageModule(BaseModel):
    type: str = ModuleType.IMAGE
    image_url: Optional[str] = None
    image_base64: Optional[str] = None
    alt_text: str = ""
    caption: Optional[str] = None


class DeepDiveModule(BaseModel):
    type: str = ModuleType.DEEP_DIVE
    topic: str = Field(..., description="Sub-topic title for deep dive")
    preview: str = Field(..., description="2-sentence preview of advanced content")


class KeyPointModule(BaseModel):
    type: str = ModuleType.KEY_POINT
    content: str
    icon: Optional[str] = "💡"


# ============================================
# API Request Models
# ============================================

class LessonRequest(BaseModel):
    topic: str = Field(..., description="The topic the user wants to learn", min_length=2, max_length=500)
    user_profile: NeuroProfileType = Field(..., description="The user's neuro-profile type")
    energy_level: EnergyLevel = Field(default=EnergyLevel.MEDIUM, description="User's current mental energy level")
    visuals_needed: bool = Field(default=True, description="Whether to generate visual aids")


class SimplifyRequest(BaseModel):
    text: str = Field(..., description="Text to simplify", min_length=10)
    user_profile: NeuroProfileType = Field(..., description="The user's neuro-profile type")


class TTSRequest(BaseModel):
    text: str = Field(..., description="Text to convert to speech", min_length=1)
    speed: float = Field(default=1.0, ge=0.5, le=2.0, description="Speech speed multiplier")
    voice: Optional[str] = Field(default=None, description="Voice name override")


class ImageAnalyzeRequest(BaseModel):
    image_base64: str = Field(..., description="Base64-encoded image data")
    user_profile: NeuroProfileType = Field(..., description="The user's neuro-profile type")


class DeepDiveRequest(BaseModel):
    parent_topic: str = Field(..., description="The parent topic for context")
    sub_topic: str = Field(..., description="The sub-topic to deep dive into")
    user_profile: NeuroProfileType = Field(..., description="The user's neuro-profile type")


# ============================================
# API Response Models
# ============================================

class LessonModule(BaseModel):
    """A single module within a lesson. Uses discriminated union pattern."""
    type: str
    content: Optional[str] = None
    section_type: Optional[str] = None
    mermaid_code: Optional[str] = None
    caption: Optional[str] = None
    question: Optional[str] = None
    answer: Optional[str] = None
    hint: Optional[str] = None
    image_url: Optional[str] = None
    image_base64: Optional[str] = None
    alt_text: Optional[str] = None
    topic: Optional[str] = None
    preview: Optional[str] = None
    icon: Optional[str] = None


class LessonResponse(BaseModel):
    title: str
    summary: str
    modules: List[LessonModule]
    tts_text: Optional[str] = Field(None, description="Full lesson as plain text for TTS")
    audio_url: Optional[str] = Field(None, description="URL to pre-generated TTS audio")
    profile_used: NeuroProfileType
    module_count: int = 0


class SimplifyResponse(BaseModel):
    original_length: int
    simplified_text: str
    modules: List[LessonModule]
    tts_text: Optional[str] = None
    audio_url: Optional[str] = None


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    service: str = "NeuroSpace Backend"


# ============================================
# NeuroProfile Models (for Firestore)
# ============================================

class NeuroProfile(BaseModel):
    profile_type: NeuroProfileType
    font_family: str = "Inter"
    font_size: float = 16.0
    letter_spacing: float = 0.0
    line_height: float = 1.5
    background_color: str = "#FFFFFF"
    text_color: str = "#1A1A1A"
    accent_color: str = "#4285F4"
    tts_speed: float = 1.0
    contrast_mode: ContrastMode = ContrastMode.NORMAL
    focus_borders_enabled: bool = False


class UserProfileRequest(BaseModel):
    user_id: str
    profile: NeuroProfile
