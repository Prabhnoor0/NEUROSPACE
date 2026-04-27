"""
NeuroSpace — LLM Core
========================
Central model pool management with automatic rate-limit rotation.
Manages both Gemini and Groq model pools.

When a 429 (rate limit) is hit on any model, it is placed in cooldown
and the pool rotates to the next available model automatically.
"""

import os
import time
import logging
import json
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Callable
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


# ============================================
# Model Pool — Auto-Rotating on Rate Limits
# ============================================

class ModelPool:
    """
    A pool of models that auto-rotates when rate limits (429) are hit.
    Each pool (text, vision, audio) has its own set of models.
    Cooldown: when a model hits 429, it's marked unavailable for N seconds.
    """

    def __init__(self, pool_name: str, models: List[str], cooldown_seconds: int = 60):
        self.pool_name = pool_name
        self.models = models
        self.current_index = 0
        self.cooldowns: Dict[str, datetime] = {}  # model -> when it becomes available
        self.cooldown_seconds = cooldown_seconds
        logger.info(f"[ModelPool:{pool_name}] Initialized with {len(models)} models: {models}")

    def get_current_model(self) -> str:
        """Get the next available model, skipping those in cooldown."""
        if not self.models:
            raise RuntimeError(f"[ModelPool:{self.pool_name}] No models configured!")

        now = datetime.now()

        for _ in range(len(self.models)):
            model = self.models[self.current_index]
            cooldown_until = self.cooldowns.get(model)

            if cooldown_until is None or now >= cooldown_until:
                # Model is available
                if model in self.cooldowns:
                    del self.cooldowns[model]
                    logger.info(f"[ModelPool:{self.pool_name}] Model '{model}' cooldown expired, reactivated.")
                return model

            # Model in cooldown, try next
            logger.debug(f"[ModelPool:{self.pool_name}] '{model}' in cooldown until {cooldown_until}")
            self.current_index = (self.current_index + 1) % len(self.models)

        # All models in cooldown — fail instantly to trigger fallback
        logger.warning(f"[ModelPool:{self.pool_name}] ALL models in cooldown! Exhausted.")
        raise RuntimeError(f"All models in {self.pool_name} pool are currently rate-limited.")

    def mark_rate_limited(self, model: str):
        """Mark a model as rate-limited. Pool rotates to the next model."""
        cooldown_until = datetime.now() + timedelta(seconds=self.cooldown_seconds)
        self.cooldowns[model] = cooldown_until
        logger.warning(
            f"[ModelPool:{self.pool_name}] ⚠️ Model '{model}' rate-limited! "
            f"Cooldown until {cooldown_until.strftime('%H:%M:%S')}. "
            f"Rotating to next model."
        )
        self.current_index = (self.current_index + 1) % len(self.models)

    def get_status(self) -> dict:
        """Get pool status for monitoring."""
        now = datetime.now()
        return {
            "pool_name": self.pool_name,
            "models": self.models,
            "current_model": self.models[self.current_index],
            "cooldowns": {
                model: f"{(until - now).total_seconds():.0f}s remaining"
                for model, until in self.cooldowns.items()
                if until > now
            },
        }


# ============================================
# Global Model Pools
# ============================================

def _parse_models(env_key: str, defaults: List[str]) -> List[str]:
    """Parse comma-separated model list from env, or use defaults."""
    raw = os.getenv(env_key, "")
    if raw.strip():
        return [m.strip() for m in raw.split(",") if m.strip()]
    return defaults


# Groq pools
groq_text_pool = ModelPool(
    "groq_text",
    _parse_models("GROQ_TEXT_MODELS", [
        "llama-3.3-70b-versatile",
        "llama3-70b-8192",
        "llama3-8b-8192",
        "mixtral-8x7b-32768",
    ]),
    cooldown_seconds=60,
)

groq_vision_pool = ModelPool(
    "groq_vision",
    _parse_models("GROQ_VISION_MODELS", [
        "llama-3.2-90b-vision-preview",
        "llama-3.2-11b-vision-preview",
    ]),
    cooldown_seconds=60,
)

groq_audio_pool = ModelPool(
    "groq_audio",
    _parse_models("GROQ_AUDIO_MODELS", [
        "whisper-large-v3",
        "whisper-large-v3-turbo",
    ]),
    cooldown_seconds=60,
)

# Gemini pools
gemini_pool = ModelPool(
    "gemini",
    _parse_models("GEMINI_MODELS", [
        os.getenv("GEMINI_FLASH_MODEL", "gemini-2.5-flash"),
        os.getenv("GEMINI_PRO_MODEL", "gemini-2.5-pro"),
    ]),
    cooldown_seconds=60,
)


# ============================================
# Groq Client
# ============================================

_groq_client = None

def get_groq_client():
    """Get or create the Groq client."""
    global _groq_client
    if _groq_client is None:
        from groq import Groq
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError("GROQ_API_KEY not set in .env file!")
        _groq_client = Groq(api_key=api_key)
        logger.info("Groq client initialized.")
    return _groq_client


# ============================================
# Gemini Client
# ============================================

_gemini_configured = False

def get_gemini_model(use_pro: bool = False):
    """Get a configured Gemini GenerativeModel instance."""
    global _gemini_configured
    import google.generativeai as genai

    if not _gemini_configured:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY not set in .env file!")
        genai.configure(api_key=api_key)
        _gemini_configured = True
        logger.info("Gemini API configured.")

    model_name = gemini_pool.get_current_model()
    return genai.GenerativeModel(model_name), model_name


# ============================================
# Groq Invocation with Auto-Fallback
# ============================================

def _is_rate_limit_error(e: Exception) -> bool:
    """Check if an exception is a rate limit (429) error."""
    error_str = str(e).lower()
    if "429" in error_str or "rate_limit" in error_str or "rate limit" in error_str:
        return True
    # Check for Groq-specific rate limit exception
    if hasattr(e, 'status_code') and e.status_code == 429:
        return True
    return False


def invoke_groq_with_fallback(
    messages: List[Dict[str, str]],
    task_name: str,
    pool: ModelPool = None,
    max_retries: int = 3,
    temperature: float = 0.1,
    max_tokens: int = 4096,
    response_format: Optional[dict] = None,
) -> Optional[str]:
    """
    Invoke Groq chat completion with automatic model rotation on rate limits.

    Args:
        messages: Chat messages (system + user)
        task_name: For logging
        pool: Which model pool to use (defaults to groq_text_pool)
        max_retries: Total retry attempts across all models
        temperature: Model temperature
        max_tokens: Max output tokens
        response_format: Optional response format (e.g., {"type": "json_object"})

    Returns:
        The model's response text, or None if all retries fail.
    """
    if pool is None:
        pool = groq_text_pool

    client = get_groq_client()

    for attempt in range(max_retries):
        model = pool.get_current_model()
        try:
            kwargs = {
                "model": model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
            }
            if response_format:
                kwargs["response_format"] = response_format

            response = client.chat.completions.create(**kwargs)
            result = response.choices[0].message.content.strip()
            logger.info(f"[{task_name}] ✅ Success with model '{model}' (attempt {attempt+1})")
            return result

        except Exception as e:
            if _is_rate_limit_error(e):
                logger.warning(f"[{task_name}] 429 on '{model}' — rotating...")
                pool.mark_rate_limited(model)
                continue  # retry with next model
            else:
                logger.error(f"[{task_name}] Non-rate-limit error on '{model}': {e}")
                if attempt < max_retries - 1:
                    time.sleep(1)
                    continue
                return None

    logger.error(f"[{task_name}] All {max_retries} retries exhausted.")
    return None


def invoke_groq_json(
    messages: List[Dict[str, str]],
    task_name: str,
    pool: ModelPool = None,
    max_retries: int = 3,
    temperature: float = 0.1,
) -> Optional[Dict]:
    """
    Invoke Groq and parse the response as JSON.
    Automatically requests JSON output format.
    """
    result = invoke_groq_with_fallback(
        messages=messages,
        task_name=task_name,
        pool=pool,
        max_retries=max_retries,
        temperature=temperature,
        response_format={"type": "json_object"},
    )

    if result is None:
        return None

    try:
        # Clean code fences if present
        text = result.strip()
        if text.startswith("```"):
            text = text.split("\n", 1)[1]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()
        return json.loads(text)
    except json.JSONDecodeError as e:
        logger.error(f"[{task_name}] Failed to parse JSON response: {e}")
        logger.debug(f"[{task_name}] Raw response: {result[:500]}")
        return None


# ============================================
# Groq Vision (Image Understanding)
# ============================================

def invoke_groq_vision(
    image_bytes: bytes,
    prompt: str,
    task_name: str = "vision_ocr",
    max_retries: int = 3,
    temperature: float = 0.2,
) -> Optional[str]:
    """
    Send an image to Groq's vision model for OCR / understanding.

    Args:
        image_bytes: Raw image bytes (JPEG/PNG)
        prompt: Text prompt describing what to extract
        task_name: For logging
        max_retries: Retry attempts
        temperature: Model temperature

    Returns:
        The model's text response, or None on failure.
    """
    import base64

    client = get_groq_client()
    b64 = base64.b64encode(image_bytes).decode("utf-8")

    messages = [
        {
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{b64}",
                    },
                },
                {
                    "type": "text",
                    "text": prompt,
                },
            ],
        }
    ]

    pool = groq_vision_pool

    for attempt in range(max_retries):
        model = pool.get_current_model()
        try:
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=4096,
            )
            result = response.choices[0].message.content.strip()
            logger.info(f"[{task_name}] ✅ Vision success with '{model}' (attempt {attempt+1})")
            return result

        except Exception as e:
            if _is_rate_limit_error(e):
                logger.warning(f"[{task_name}] 429 on vision '{model}' — rotating...")
                pool.mark_rate_limited(model)
                continue
            else:
                logger.error(f"[{task_name}] Vision error on '{model}': {e}")
                if attempt < max_retries - 1:
                    time.sleep(1)
                    continue
                return None

    logger.error(f"[{task_name}] All {max_retries} vision retries exhausted.")
    return None


# ============================================
# Gemini Invocation with Auto-Fallback
# ============================================

def invoke_gemini_with_fallback(
    prompt: str,
    task_name: str,
    max_retries: int = 3,
    temperature: float = 0.7,
    max_output_tokens: int = 8192,
    response_mime_type: str = "application/json",
) -> Optional[str]:
    """
    Invoke Gemini with automatic model rotation on rate limits.

    Args:
        prompt: The prompt text
        task_name: For logging
        max_retries: Total retry attempts
        temperature: Model temperature
        max_output_tokens: Max output tokens
        response_mime_type: Response format (application/json for structured output)

    Returns:
        The model's response text, or None if all retries fail.
    """
    import google.generativeai as genai

    # Ensure configured
    try:
        get_gemini_model()  # triggers configuration
    except Exception as e:
        logger.error(f"[{task_name}] Gemini configuration failed: {e}")
        return None

    for attempt in range(max_retries):
        try:
            model_name = gemini_pool.get_current_model()
            model = genai.GenerativeModel(
                model_name=model_name,
                generation_config=genai.GenerationConfig(
                    temperature=temperature,
                    max_output_tokens=max_output_tokens,
                    response_mime_type=response_mime_type,
                ),
            )

            response = model.generate_content(prompt)
            result = response.text.strip()
            logger.info(f"[{task_name}] ✅ Success with Gemini '{model_name}' (attempt {attempt+1})")
            return result

        except RuntimeError as e:
            # Pool exhausted — all models rate-limited
            logger.warning(f"[{task_name}] Gemini pool exhausted: {e}")
            return None
        except Exception as e:
            model_name = getattr(e, '_model_name', 'unknown')
            if _is_rate_limit_error(e):
                logger.warning(f"[{task_name}] 429 on Gemini — rotating...")
                try:
                    gemini_pool.mark_rate_limited(gemini_pool.models[gemini_pool.current_index])
                except Exception:
                    pass
                continue
            else:
                logger.error(f"[{task_name}] Gemini error: {e}")
                if attempt < max_retries - 1:
                    time.sleep(1)
                    continue
                return None

    logger.error(f"[{task_name}] All Gemini retries exhausted.")
    return None


def invoke_gemini_json(
    prompt: str,
    task_name: str,
    max_retries: int = 3,
    temperature: float = 0.7,
) -> Optional[Dict]:
    """
    Invoke Gemini and parse as JSON.
    """
    result = invoke_gemini_with_fallback(
        prompt=prompt,
        task_name=task_name,
        max_retries=max_retries,
        temperature=temperature,
        response_mime_type="application/json",
    )

    if result is None:
        return None

    try:
        text = result.strip()
        if text.startswith("```"):
            text = text.split("\n", 1)[1]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()
        return json.loads(text)
    except json.JSONDecodeError as e:
        logger.error(f"[{task_name}] Failed to parse Gemini JSON: {e}")
        logger.debug(f"[{task_name}] Raw: {result[:500]}")
        return None


def invoke_gemini_with_image(
    prompt: str,
    image_bytes: bytes,
    task_name: str,
    mime_type: str = "image/jpeg",
    max_retries: int = 3,
) -> Optional[str]:
    """
    Invoke Gemini with an image (vision task).
    """
    import google.generativeai as genai

    get_gemini_model()  # ensure configured

    for attempt in range(max_retries):
        model_name = gemini_pool.get_current_model()
        try:
            model = genai.GenerativeModel(
                model_name=model_name,
                generation_config=genai.GenerationConfig(
                    temperature=0.5,
                    max_output_tokens=8192,
                    response_mime_type="application/json",
                ),
            )

            response = model.generate_content([
                prompt,
                {"mime_type": mime_type, "data": image_bytes},
            ])
            result = response.text.strip()
            logger.info(f"[{task_name}] ✅ Gemini vision success with '{model_name}'")
            return result

        except Exception as e:
            if _is_rate_limit_error(e):
                logger.warning(f"[{task_name}] 429 on Gemini vision '{model_name}' — rotating...")
                gemini_pool.mark_rate_limited(model_name)
                continue
            else:
                logger.error(f"[{task_name}] Gemini vision error: {e}")
                if attempt < max_retries - 1:
                    time.sleep(1)
                return None

    return None


# ============================================
# Pool Status (for health/monitoring endpoint)
# ============================================

def get_all_pool_status() -> dict:
    """Get status of all model pools for monitoring."""
    return {
        "groq_text": groq_text_pool.get_status(),
        "groq_vision": groq_vision_pool.get_status(),
        "groq_audio": groq_audio_pool.get_status(),
        "gemini": gemini_pool.get_status(),
    }
