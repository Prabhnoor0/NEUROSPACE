"""
NeuroSpace — Text-to-Speech Router
=====================================
Handles TTS audio generation using Gemini 3.1 Flash TTS (free).
Returns either streaming WAV audio or a Cloudinary URL.
"""

import logging
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
import io

from models.schemas import TTSRequest
from services import tts_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Generate Speech Audio (streaming WAV)
# ============================================

@router.post("/text-to-speech")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to natural-sounding speech using Gemini 3.1 Flash TTS (free).

    Returns WAV audio as a streaming response that can be played
    directly by the Flutter audioplayers package.

    Profile-aware: ADHD=Puck (energetic), Dyslexia=Kore (clear), Autism=Enceladus (calm).
    """
    try:
        audio_bytes = await tts_service.synthesize_speech(
            text=request.text,
            speed=request.speed,
            voice_name=request.voice,
        )

        audio_stream = io.BytesIO(audio_bytes)

        return StreamingResponse(
            audio_stream,
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=neurospace_tts.wav",
                "Content-Length": str(len(audio_bytes)),
            },
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"TTS generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate speech: {str(e)}"
        )


# ============================================
# Generate Speech and Upload to Cloudinary (returns URL)
# ============================================

@router.post("/text-to-speech/url")
async def text_to_speech_url(request: TTSRequest):
    """
    Convert text to speech via Gemini TTS and upload to Cloudinary.
    Returns a JSON response with the audio URL for persistent playback.
    """
    try:
        result = await tts_service.synthesize_and_upload(
            text=request.text,
            speed=request.speed,
        )

        if result.get("audio_url"):
            return {
                "status": "success",
                "audio_url": result["audio_url"],
                "size_bytes": result["size_bytes"],
            }
        else:
            return {
                "status": "no_cloudinary",
                "message": "Audio generated but Cloudinary upload failed. Use /text-to-speech for streaming.",
                "audio_url": None,
            }

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"TTS URL generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate speech URL: {str(e)}"
        )


# ============================================
# Generate Speech for Full Lesson
# ============================================

@router.post("/text-to-speech/lesson")
async def lesson_to_speech(request: TTSRequest):
    """
    Convert a full lesson's text to speech via Gemini TTS.
    Handles long text by splitting into chunks and concatenating audio.
    """
    try:
        audio_bytes = await tts_service.synthesize_long_text(
            text=request.text,
            speed=request.speed,
        )

        audio_stream = io.BytesIO(audio_bytes)

        return StreamingResponse(
            audio_stream,
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=neurospace_lesson.wav",
                "Content-Length": str(len(audio_bytes)),
            },
        )

    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Lesson TTS generation failed: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate lesson speech: {str(e)}"
        )
