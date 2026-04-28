"""
NeuroSpace Backend - Main FastAPI Application
=============================================
The command center that orchestrates Gemini, Groq, Cloud TTS,
and Imagen to generate adaptive learning content for
neurodivergent users.
"""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from models.schemas import HealthResponse

# Load environment variables
load_dotenv()

# ============================================
# App Initialization
# ============================================

app = FastAPI(
    title="NeuroSpace API",
    description=(
        "Adaptive learning backend for neurodivergent users. "
        "Powered by Google Gemini, Groq, Cloud TTS, and Imagen."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ============================================
# CORS Middleware
# ============================================

allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Open for development; restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# Health Check
# ============================================

@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health_check():
    """Health check endpoint to verify the backend is running."""
    return HealthResponse(
        status="ok",
        version="1.0.0",
        service="NeuroSpace Backend"
    )


@app.get("/", tags=["System"])
async def root():
    """Root endpoint with API info."""
    return {
        "message": "🧠 NeuroSpace API is running!",
        "docs": "/docs",
        "health": "/health",
        "version": "1.0.0"
    }


# ============================================
# Model Pool Status Endpoint
# ============================================

@app.get("/model-status", tags=["System"])
async def model_status():
    """View the status of all model pools (current model, cooldowns)."""
    from services.llm_core import get_all_pool_status
    return get_all_pool_status()


# ============================================
# Router Registration
# ============================================

from routers import lessons, simplify, tts, image, theme, maps, scan, search, voice, assistant, resources
app.include_router(lessons.router, prefix="/api", tags=["Lessons"])
app.include_router(simplify.router, prefix="/api", tags=["Simplify"])
app.include_router(tts.router, prefix="/api", tags=["Text-to-Speech"])
app.include_router(image.router, prefix="/api", tags=["Image Generation"])
app.include_router(theme.router, prefix="/api", tags=["Theme Generation"])
app.include_router(maps.router, prefix="/api", tags=["Maps"])
app.include_router(scan.router, prefix="/api", tags=["Image Scan & Simplify"])
app.include_router(search.router, prefix="/api", tags=["Search"])
app.include_router(voice.router, prefix="/api", tags=["Voice Assistant"])
app.include_router(assistant.router, prefix="/api", tags=["Assistant"])
app.include_router(resources.router, prefix="/api", tags=["Resource Assistant"])


# ============================================
# Startup / Shutdown Events
# ============================================

@app.on_event("startup")
async def startup_event():
    """Initialize services on app startup."""
    from services.llm_core import (
        gemini_pool, groq_text_pool, groq_vision_pool, groq_audio_pool
    )
    from services.cloudinary_service import is_configured as cloudinary_ok
    print("🧠 NeuroSpace Backend starting up...")
    print(f"   Gemini API Key:  {'SET ✅' if os.getenv('GEMINI_API_KEY') else 'NOT SET ❌'}")
    print(f"   Groq API Key:    {'SET ✅' if os.getenv('GROQ_API_KEY') else 'NOT SET ❌'}")
    print(f"   Cloudinary:      {'SET ✅' if cloudinary_ok() else 'NOT SET ❌'}")
    print(f"   Gemini Models:   {gemini_pool.models}")
    print(f"   Groq Text:       {groq_text_pool.models}")
    print(f"   Groq Vision:     {groq_vision_pool.models}")
    print(f"   Groq Audio:      {groq_audio_pool.models}")
    print(f"   Debug Mode:      {os.getenv('DEBUG', 'false')}")
    print("✅ NeuroSpace Backend ready!")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    print("🛑 NeuroSpace Backend shutting down...")


# ============================================
# Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
# ============================================
