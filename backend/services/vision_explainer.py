"""
NeuroSpace — Vision Explainer
================================
Explains images in plain language for neurodivergent users.
Uses Groq Vision with auto-model-rotation on rate limits.
"""

import logging
from .llm_core import get_groq_client, groq_vision_pool

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an accessibility assistant for neurodivergent users (ADHD, Dyslexia, Autism).
Describe this image in simple, plain language. Focus on:
- What is being shown (type of diagram, chart, photo, etc.)
- Key relationships, patterns, or data points
- Labels and their meanings
- Any important takeaways

Keep your explanation under 150 words. Use short sentences. Avoid jargon.
If the image appears to be decorative or a logo, say so briefly."""


def explain_image(image_base64: str, context: str = "") -> str:
    """
    Send a base64-encoded image to Groq Vision for plain-language explanation.
    Auto-rotates to backup vision model on rate limit.
    """
    max_retries = 3
    client = get_groq_client()

    if not image_base64.startswith("data:"):
        image_base64 = f"data:image/png;base64,{image_base64}"

    user_content = [
        {
            "type": "image_url",
            "image_url": {
                "url": image_base64
            }
        },
        {
            "type": "text",
            "text": f"Explain this image simply.{(' Context from the page: ' + context[:300]) if context else ''}"
        }
    ]

    for attempt in range(max_retries):
        model = groq_vision_pool.get_current_model()
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_content}
                ],
                max_tokens=300,
                temperature=0.3,
            )
            result = response.choices[0].message.content.strip()
            logger.info(f"[vision_explainer] ✅ Success with '{model}'")
            return result

        except Exception as e:
            error_str = str(e).lower()
            if "429" in error_str or "rate_limit" in error_str or "rate limit" in error_str:
                logger.warning(f"[vision_explainer] 429 on '{model}' — rotating...")
                groq_vision_pool.mark_rate_limited(model)
                continue
            else:
                logger.error(f"[vision_explainer] Error on '{model}': {e}")
                if attempt < max_retries - 1:
                    continue
                return f"Could not analyze this image: {str(e)}"

    return "Could not analyze this image after multiple attempts."
