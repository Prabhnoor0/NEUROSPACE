"""
NeuroSpace — Gemini Service
==============================
Handles all interactions with Google Gemini models via google-generativeai.
Generates adaptive lessons, simplifies text, and analyzes images.
Uses the ModelPool for automatic rate-limit rotation.
"""

import os
import json
import base64
import logging
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

from .llm_core import (
    invoke_gemini_json,
    invoke_gemini_with_fallback,
    invoke_gemini_with_image,
)

from prompts.adhd_prompt import ADHD_SYSTEM_PROMPT, ADHD_TOPIC_TEMPLATE
from prompts.dyslexia_prompt import DYSLEXIA_SYSTEM_PROMPT, DYSLEXIA_TOPIC_TEMPLATE
from prompts.autism_prompt import AUTISM_SYSTEM_PROMPT, AUTISM_TOPIC_TEMPLATE


# ============================================
# Profile → Prompt Mapping
# ============================================

PROFILE_PROMPTS = {
    "ADHD": {
        "system": ADHD_SYSTEM_PROMPT,
        "template": ADHD_TOPIC_TEMPLATE,
    },
    "Dyslexia": {
        "system": DYSLEXIA_SYSTEM_PROMPT,
        "template": DYSLEXIA_TOPIC_TEMPLATE,
    },
    "Autism": {
        "system": AUTISM_SYSTEM_PROMPT,
        "template": AUTISM_TOPIC_TEMPLATE,
    },
}


# ============================================
# Core Lesson Generation
# ============================================

async def generate_lesson(
    topic: str,
    profile: str,
    energy_level: str = "Medium",
    visuals_needed: bool = True,
) -> dict:
    """
    Generate an adaptive lesson using Gemini with auto-fallback.

    Args:
        topic: The topic to teach
        profile: "ADHD", "Dyslexia", or "Autism"
        energy_level: "High", "Medium", or "Low"
        visuals_needed: Whether to include image generation prompts

    Returns:
        Structured lesson dict with modules
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]
    topic_prompt = prompt_config["template"].format(
        topic=topic,
        energy_level=energy_level,
        visuals_needed=visuals_needed,
    )

    full_prompt = f"{system_prompt}\n\n{topic_prompt}"

    lesson_data = invoke_gemini_json(
        prompt=full_prompt,
        task_name="lesson_generation",
        temperature=0.7,
    )

    if lesson_data and "title" in lesson_data and "modules" in lesson_data:
        logger.info(
            f"Generated lesson: '{lesson_data.get('title')}' "
            f"with {len(lesson_data.get('modules', []))} modules "
            f"for profile={profile}"
        )
        return lesson_data

    # Retry with stricter prompt
    return await _retry_with_strict_prompt(topic, profile, energy_level)


async def _retry_with_strict_prompt(
    topic: str, profile: str, energy_level: str
) -> dict:
    """Retry lesson generation with a stricter JSON-enforcement prompt."""
    strict_addition = (
        "\n\nPREVIOUS ATTEMPT FAILED — your response was not valid JSON. "
        "This time, return ONLY a raw JSON object. No markdown. No explanation. "
        "Start with { and end with }. Nothing else."
    )

    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]
    topic_prompt = prompt_config["template"].format(
        topic=topic,
        energy_level=energy_level,
        visuals_needed=True,
    ) + strict_addition

    full_prompt = f"{system_prompt}\n\n{topic_prompt}"

    lesson_data = invoke_gemini_json(
        prompt=full_prompt,
        task_name="lesson_generation_retry",
        temperature=0.5,
    )

    if lesson_data and "title" in lesson_data:
        return lesson_data

    # Return a minimal fallback lesson
    return {
        "title": f"Lesson: {topic}",
        "summary": f"An overview of {topic}.",
        "modules": [
            {
                "type": "text_block",
                "content": f"We encountered an issue generating the full lesson for **{topic}**. "
                           "Please try again or rephrase your topic.",
                "section_type": "explanation",
            }
        ],
        "tts_text": f"We encountered an issue generating the lesson for {topic}. Please try again.",
    }


# ============================================
# Simplification (now using Gemini)
# ============================================

async def simplify_text(text: str, profile: str) -> dict:
    """
    Simplify complex text based on the user's neuro-profile using Gemini.

    Args:
        text: The complex text to simplify
        profile: "ADHD", "Dyslexia", or "Autism"

    Returns:
        Structured simplified content as lesson modules
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]

    simplify_prompt = f"""{system_prompt}

The user has shared the following text and needs it simplified for their learning style.
Restructure this text into your standard lesson module JSON format.

TEXT TO SIMPLIFY:
\"\"\"
{text}
\"\"\"

Return the JSON lesson structure with "title", "summary", "modules", and "tts_text" fields.
Return ONLY valid JSON, no extra text.
"""

    lesson_data = invoke_gemini_json(
        prompt=simplify_prompt,
        task_name="text_simplification",
        temperature=0.5,
    )

    if lesson_data:
        return lesson_data

    raise RuntimeError("Failed to simplify text after all retries.")


# ============================================
# Image Analysis (Gemini Vision)
# ============================================

async def analyze_image(image_base64: str, profile: str) -> dict:
    """
    Analyze an image (e.g., textbook photo) and generate an adaptive lesson.

    Args:
        image_base64: Base64-encoded image
        profile: "ADHD", "Dyslexia", or "Autism"

    Returns:
        Structured lesson based on image content
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]

    vision_prompt = f"""{system_prompt}

The user has taken a photo of educational material. Analyze the image:
1. Extract all text visible in the image.
2. Identify the core concepts, diagrams, or formulas shown.
3. Restructure the content into your standard lesson module JSON format.
4. If there are diagrams, recreate them as Mermaid.js code.
5. Simplify the content according to the student's learning profile.

Return ONLY valid JSON in your standard lesson format with "title", "summary", "modules", and "tts_text".
"""

    image_bytes = base64.b64decode(image_base64)

    result_text = invoke_gemini_with_image(
        prompt=vision_prompt,
        image_bytes=image_bytes,
        task_name="image_analysis",
        mime_type="image/jpeg",
    )

    if result_text:
        try:
            text = result_text.strip()
            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                if text.endswith("```"):
                    text = text[:-3]
                text = text.strip()
            return json.loads(text)
        except json.JSONDecodeError as e:
            logger.error(f"Image analysis returned invalid JSON: {e}")

    raise RuntimeError("Failed to analyze image after all retries.")


# ============================================
# Deep Dive Sub-Lesson
# ============================================

async def generate_deep_dive(
    parent_topic: str, sub_topic: str, profile: str
) -> dict:
    """
    Generate a deep-dive sub-lesson for a specific sub-topic.

    Args:
        parent_topic: The original parent topic for context
        sub_topic: The specific sub-topic to expand
        profile: "ADHD", "Dyslexia", or "Autism"

    Returns:
        Structured sub-lesson dict
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]

    deep_dive_prompt = f"""{system_prompt}

Context: The student is learning about "{parent_topic}" and wants to explore
the sub-topic "{sub_topic}" in greater detail.

Generate a focused, detailed lesson on "{sub_topic}" within the context of "{parent_topic}".
Include further deep_dive modules for even more specific sub-topics.
This allows infinite depth of exploration.

Return ONLY valid JSON in your standard lesson format with "title", "summary", "modules", and "tts_text".
"""

    lesson_data = invoke_gemini_json(
        prompt=deep_dive_prompt,
        task_name="deep_dive",
        temperature=0.7,
    )

    if lesson_data:
        return lesson_data

    raise RuntimeError("Failed to generate deep dive after all retries.")
