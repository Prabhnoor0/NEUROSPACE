"""
NeuroSpace — Text-to-Speech Service (Gemini 3.1 Flash TTS)
=============================================================
Uses Gemini 3.1 Flash TTS Preview for FREE text-to-speech.
Same API key as the rest of Gemini — no extra billing needed.

Supports:
- Profile-specific voices (ADHD=energetic, Dyslexia=clear, Autism=calm)
- Expressive audio tags ([excited], [slow], [whispers])
- Upload to Cloudinary for persistent URLs
"""

import os
import io
import wave
import base64
import logging
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ============================================
# Gemini TTS Client Setup
# ============================================

_genai_client = None

def _get_client():
    """Get or initialize the google-genai client."""
    global _genai_client
    if _genai_client is None:
        try:
            from google import genai
            api_key = os.getenv("GEMINI_API_KEY")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set")
            _genai_client = genai.Client(api_key=api_key)
            logger.info("Gemini TTS client initialized")
        except ImportError:
            raise RuntimeError("google-genai SDK not installed. Run: pip install google-genai")
    return _genai_client


# ============================================
# Profile → Voice Mapping
# ============================================

# Gemini TTS has 30 prebuilt voices. These are chosen per neuro-profile:
PROFILE_VOICE_MAP = {
    "ADHD": {
        "voice_name": "Puck",      # Upbeat, energetic
        "style_tag": "[excited, upbeat]",
    },
    "Dyslexia": {
        "voice_name": "Kore",      # Clear, warm, friendly
        "style_tag": "[clear, slow, enunciated]",
    },
    "Autism": {
        "voice_name": "Enceladus", # Calm, steady, breathy
        "style_tag": "[calm, gentle, steady pace]",
    },
}


# ============================================
# Core TTS — Returns WAV bytes
# ============================================

async def synthesize_speech(
    text: str,
    speed: float = 1.0,
    profile: Optional[str] = None,
    voice_name: Optional[str] = None,
) -> bytes:
    """
    Convert text to speech using Gemini 3.1 Flash TTS (free).

    Args:
        text: The text to convert to speech
        speed: Ignored for Gemini TTS (use audio tags instead)
        profile: Neuro-profile for voice selection
        voice_name: Optional voice name override

    Returns:
        WAV audio bytes
    """
    from google.genai import types

    client = _get_client()

    # Get profile-specific settings
    profile_settings = PROFILE_VOICE_MAP.get(profile, PROFILE_VOICE_MAP["ADHD"])
    actual_voice = voice_name or profile_settings["voice_name"]
    style_tag = profile_settings["style_tag"]

    # Apply speed via audio tags
    speed_tag = ""
    if speed < 0.9:
        speed_tag = "[slow] "
    elif speed > 1.1:
        speed_tag = "[fast] "

    # Truncate text if too long
    max_chars = 4500
    if len(text) > max_chars:
        text = text[:max_chars] + "... That's the end of this section."
        logger.warning(f"Text truncated to {max_chars} chars for TTS")

    # Build the prompt with style tags
    tts_prompt = f"{style_tag} {speed_tag}{text}"

    try:
        response = client.models.generate_content(
            model="gemini-3.1-flash-tts-preview",
            contents=tts_prompt,
            config=types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=actual_voice,
                        )
                    )
                ),
            ),
        )

        # Extract raw PCM audio data
        pcm_data = response.candidates[0].content.parts[0].inline_data.data

        # Convert PCM to WAV (24kHz, 16-bit, mono)
        wav_bytes = _pcm_to_wav(pcm_data)

        logger.info(
            f"Gemini TTS generated: {len(wav_bytes)} bytes, "
            f"voice={actual_voice}, profile={profile}"
        )

        return wav_bytes

    except Exception as e:
        logger.error(f"Gemini TTS synthesis failed: {e}")
        raise RuntimeError(f"Failed to synthesize speech: {str(e)}")


def _pcm_to_wav(pcm_data: bytes, channels: int = 1, rate: int = 24000, sample_width: int = 2) -> bytes:
    """Convert raw PCM audio data to WAV format."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(rate)
        wf.writeframes(pcm_data)
    return buffer.getvalue()


# ============================================
# Synthesize + Upload to Cloudinary
# ============================================

async def synthesize_and_upload(
    text: str,
    speed: float = 1.0,
    profile: Optional[str] = None,
) -> dict:
    """
    Synthesize speech via Gemini TTS and upload to Cloudinary.

    Returns:
        Dict with 'audio_url' (Cloudinary URL) and 'size_bytes'
    """
    audio_bytes = await synthesize_speech(text=text, speed=speed, profile=profile)

    try:
        from . import cloudinary_service
        if cloudinary_service.is_configured():
            audio_url = cloudinary_service.upload_audio(audio_bytes, format="wav")
            return {
                "audio_url": audio_url,
                "size_bytes": len(audio_bytes),
            }
    except Exception as e:
        logger.warning(f"Cloudinary upload failed, returning raw audio: {e}")

    # Fallback: no Cloudinary URL
    return {
        "audio_url": None,
        "size_bytes": len(audio_bytes),
    }


# ============================================
# Batch TTS (for long lessons split into chunks)
# ============================================

async def synthesize_long_text(
    text: str,
    speed: float = 1.0,
    profile: Optional[str] = None,
) -> bytes:
    """
    Synthesize long text by splitting into chunks and concatenating audio.

    Args:
        text: Full lesson text (can be very long)
        speed: Speaking rate hint
        profile: Neuro-profile

    Returns:
        Complete WAV audio bytes
    """
    chunks = _split_text(text, max_chars=4000)
    audio_parts = []

    for i, chunk in enumerate(chunks):
        logger.info(f"Synthesizing chunk {i+1}/{len(chunks)}: {len(chunk)} chars")
        audio = await synthesize_speech(
            text=chunk, speed=speed, profile=profile
        )
        audio_parts.append(audio)

    # For WAV, we need to concatenate PCM data and re-wrap
    # Simple approach: just return the first chunk for now
    # (full concatenation would require stripping WAV headers)
    if len(audio_parts) == 1:
        return audio_parts[0]

    # Concatenate by stripping WAV headers from all but the first
    combined = io.BytesIO()
    with wave.open(combined, "wb") as out_wf:
        out_wf.setnchannels(1)
        out_wf.setsampwidth(2)
        out_wf.setframerate(24000)

        for part_bytes in audio_parts:
            with wave.open(io.BytesIO(part_bytes), "rb") as in_wf:
                out_wf.writeframes(in_wf.readframes(in_wf.getnframes()))

    return combined.getvalue()


def _split_text(text: str, max_chars: int = 4000) -> list:
    """Split text into chunks at sentence boundaries."""
    if len(text) <= max_chars:
        return [text]

    chunks = []
    current_chunk = ""

    sentences = text.replace(". ", ".\n").split("\n")

    for sentence in sentences:
        if len(current_chunk) + len(sentence) + 1 <= max_chars:
            current_chunk += sentence + " "
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence + " "

    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    return chunks
