"""
NeuroSpace — Cloudinary Service
==================================
Handles media uploads (TTS audio, generated images) to Cloudinary.
Free tier: 25GB storage, 25GB bandwidth/month.
"""

import os
import io
import logging
import uuid
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

_configured = False


def _ensure_configured():
    """Configure Cloudinary on first use."""
    global _configured
    if _configured:
        return

    import cloudinary
    import cloudinary.uploader

    cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME")
    api_key = os.getenv("CLOUDINARY_API_KEY")
    api_secret = os.getenv("CLOUDINARY_API_SECRET")

    if not all([cloud_name, api_key, api_secret]):
        raise RuntimeError(
            "Cloudinary not configured! Set CLOUDINARY_CLOUD_NAME, "
            "CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in .env"
        )

    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret,
        secure=True,
    )
    _configured = True
    logger.info(f"Cloudinary configured: cloud_name={cloud_name}")


def upload_audio(audio_bytes: bytes, filename: Optional[str] = None) -> str:
    """
    Upload MP3 audio bytes to Cloudinary.

    Args:
        audio_bytes: Raw MP3 audio data
        filename: Optional filename (auto-generated if not provided)

    Returns:
        Public URL to the uploaded audio file
    """
    _ensure_configured()
    import cloudinary.uploader

    if not filename:
        filename = f"neurospace_tts_{uuid.uuid4().hex[:8]}"

    try:
        result = cloudinary.uploader.upload(
            io.BytesIO(audio_bytes),
            resource_type="video",  # Cloudinary uses "video" for audio files
            public_id=f"neurospace/audio/{filename}",
            folder="neurospace/audio",
            format="mp3",
            overwrite=True,
        )

        url = result.get("secure_url", result.get("url", ""))
        logger.info(f"Audio uploaded to Cloudinary: {len(audio_bytes)} bytes → {url}")
        return url

    except Exception as e:
        logger.error(f"Cloudinary audio upload failed: {e}")
        raise RuntimeError(f"Failed to upload audio: {str(e)}")


def upload_image(image_bytes: bytes, filename: Optional[str] = None) -> str:
    """
    Upload image bytes to Cloudinary.

    Args:
        image_bytes: Raw image data (PNG/JPEG)
        filename: Optional filename (auto-generated if not provided)

    Returns:
        Public URL to the uploaded image
    """
    _ensure_configured()
    import cloudinary.uploader

    if not filename:
        filename = f"neurospace_img_{uuid.uuid4().hex[:8]}"

    try:
        result = cloudinary.uploader.upload(
            io.BytesIO(image_bytes),
            resource_type="image",
            public_id=f"neurospace/images/{filename}",
            folder="neurospace/images",
            overwrite=True,
        )

        url = result.get("secure_url", result.get("url", ""))
        logger.info(f"Image uploaded to Cloudinary: {len(image_bytes)} bytes → {url}")
        return url

    except Exception as e:
        logger.error(f"Cloudinary image upload failed: {e}")
        raise RuntimeError(f"Failed to upload image: {str(e)}")


def is_configured() -> bool:
    """Check if Cloudinary credentials are set."""
    return all([
        os.getenv("CLOUDINARY_CLOUD_NAME"),
        os.getenv("CLOUDINARY_API_KEY"),
        os.getenv("CLOUDINARY_API_SECRET"),
    ])
