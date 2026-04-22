"""
NeuroSpace — Voice Transcriber
=================================
Transcribes audio using Groq Whisper with auto-model-rotation.
"""

import logging
from .llm_core import get_groq_client, groq_audio_pool

logger = logging.getLogger(__name__)

# Common hallucination outputs from Whisper on silence/noise
HALLUCINATIONS = {
    "thank you.", "thank you", "thanks for watching.", "thanks for watching!",
    "please subscribe.", "subscribe.", "you", "bye.", ""
}


def transcribe_audio(audio_bytes: bytes, filename: str = "recording.webm") -> str:
    """
    Takes raw audio bytes and uses Groq Whisper to transcribe them.
    Auto-rotates to backup Whisper model on rate limit.
    """
    max_retries = 3
    client = get_groq_client()

    for attempt in range(max_retries):
        model = groq_audio_pool.get_current_model()
        try:
            transcription = client.audio.transcriptions.create(
                file=(filename, audio_bytes),
                model=model,
                response_format="text",
                language="en",
                temperature=0.0,
            )

            result = transcription.strip() if isinstance(transcription, str) else transcription.text.strip()

            # Filter out hallucinations
            if result.lower() in HALLUCINATIONS:
                logger.info(f"[voice_transcriber] Filtered hallucination: '{result}'")
                return ""

            logger.info(f"[voice_transcriber] ✅ Transcribed with '{model}': {result[:50]}...")
            return result

        except Exception as e:
            error_str = str(e).lower()
            if "429" in error_str or "rate_limit" in error_str or "rate limit" in error_str:
                logger.warning(f"[voice_transcriber] 429 on '{model}' — rotating...")
                groq_audio_pool.mark_rate_limited(model)
                continue
            else:
                logger.error(f"[voice_transcriber] Error on '{model}': {e}")
                if attempt < max_retries - 1:
                    continue
                return ""

    logger.error("[voice_transcriber] All retries exhausted.")
    return ""
