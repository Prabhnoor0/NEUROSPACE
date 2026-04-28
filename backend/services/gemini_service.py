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
    invoke_groq_json,
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
    Generate an adaptive lesson. Tries Gemini first, falls back to Groq.
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]
    topic_prompt = prompt_config["template"].format(
        topic=topic,
        energy_level=energy_level,
        visuals_needed=visuals_needed,
    )

    full_prompt = f"{system_prompt}\n\n{topic_prompt}"

    # ---- Attempt 1: Gemini ----
    try:
        lesson_data = invoke_gemini_json(
            prompt=full_prompt,
            task_name="lesson_generation",
            temperature=0.7,
        )

        if lesson_data and "title" in lesson_data and "modules" in lesson_data:
            logger.info(
                f"Generated lesson: '{lesson_data.get('title')}' "
                f"with {len(lesson_data.get('modules', []))} modules "
                f"for profile={profile} (via Gemini)"
            )
            return lesson_data
        else:
            logger.warning("Gemini returned incomplete/empty data.")
    except Exception as e:
        logger.warning(f"Gemini failed with error: {e}")

    # ---- Attempt 2: Groq fallback (auto-rotates through 4 models) ----
    logger.info("⚡ Falling back to Groq for lesson generation...")

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": topic_prompt},
    ]

    try:
        groq_data = invoke_groq_json(
            messages=messages,
            task_name="lesson_generation_groq",
            temperature=0.7,
        )

        if groq_data and "title" in groq_data and "modules" in groq_data:
            logger.info(f"✅ Generated lesson via Groq for: {topic}")
            return groq_data
        else:
            logger.warning("Groq returned incomplete data, trying strict prompt...")
    except Exception as e:
        logger.warning(f"Groq first attempt failed: {e}")

    # ---- Attempt 3: Groq with stricter prompt ----
    strict_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": topic_prompt + (
            "\n\nIMPORTANT: Return ONLY a raw JSON object. No markdown. No explanation. "
            "Start with { and end with }. The JSON must have 'title', 'summary', "
            "'modules' (array), and 'tts_text' fields."
        )},
    ]

    try:
        groq_strict = invoke_groq_json(
            messages=strict_messages,
            task_name="lesson_generation_groq_strict",
            temperature=0.5,
        )

        if groq_strict and "title" in groq_strict:
            logger.info(f"✅ Generated lesson via Groq (strict) for: {topic}")
            return groq_strict
    except Exception as e:
        logger.warning(f"Groq strict attempt also failed: {e}")

    # ---- All attempts failed — return minimal fallback ----
    logger.error(f"ALL lesson generation attempts failed for topic: {topic}")
    return _fallback_lesson(topic)


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

    # Also retry Groq if Gemini strict retry failed
    logger.warning("Gemini strict retry failed. Falling back to Groq strict retry...")
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": topic_prompt}
    ]
    groq_data = invoke_groq_json(
        messages=messages,
        task_name="lesson_generation_groq_retry",
        temperature=0.5,
    )
    
    if groq_data and "title" in groq_data:
        return groq_data

    # Return a minimal fallback lesson
    return _fallback_lesson(topic)


def _fallback_lesson(topic: str) -> dict:
    """Return a minimal fallback lesson when all AI models fail.
    Includes all unified schema fields for frontend compatibility."""
    return {
        "title": f"Lesson: {topic}",
        "summary": f"An overview of {topic}.",
        "key_points": [
            f"{topic} is an important concept worth understanding.",
            "Try searching again for a more detailed lesson.",
        ],
        "modules": [
            {
                "type": "text_block",
                "content": f"We encountered an issue generating the full lesson for **{topic}**. "
                           "Please try again or rephrase your topic.",
                "section_type": "explanation",
            }
        ],
        "wikipedia_links": [],
        "interactive": {
            "questions": [],
            "quiz": [],
        },
        "accessibility": {
            "simplified_text": f"This lesson is about {topic}. We couldn't generate full content right now. Please try again.",
            "audio_script": f"This lesson is about {topic}. Unfortunately, we had trouble generating the full content. Please try again later.",
        },
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

    # Attempt 1: Gemini
    lesson_data = invoke_gemini_json(
        prompt=simplify_prompt,
        task_name="text_simplification",
        temperature=0.5,
    )
    if lesson_data and "modules" in lesson_data:
        return lesson_data

    # Attempt 2: Groq fallback
    logger.warning("Gemini simplify failed. Trying Groq fallback...")
    groq_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": simplify_prompt},
    ]
    groq_data = invoke_groq_json(
        messages=groq_messages,
        task_name="text_simplification_groq",
        temperature=0.4,
    )
    if groq_data and "modules" in groq_data:
        return groq_data

    logger.error("All simplify model attempts failed. Returning local fallback content.")
    return _fallback_simplified_text(text)


def _fallback_simplified_text(text: str) -> dict:
    """Return a minimal simplified response when model providers are unavailable."""
    cleaned = " ".join(text.split())
    preview = cleaned[:400]
    if len(cleaned) > 400:
        preview += "..."

    return {
        "title": "Quick Summary",
        "summary": "Backend AI models are temporarily busy. Showing a basic simplification.",
        "modules": [
            {
                "type": "text_block",
                "section_type": "summary",
                "content": preview or "No text provided.",
            },
            {
                "type": "key_point",
                "content": "Try again in a few seconds for a richer AI simplification.",
                "icon": "💡",
            },
        ],
        "tts_text": preview or "No text provided.",
    }


async def summarize_text(text: str, profile: str, source_type: str = "page") -> dict:
    """
    Summarize text into a clean, structured JSON format for the UI.
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]

    summarize_prompt = f"""{system_prompt}

The user wants a clean, premium summary of the following text.
Please read it and provide a structured JSON response.

TEXT TO SUMMARIZE:
\"\"\"
{text}
\"\"\"

Return ONLY a valid JSON object matching this schema exactly. Do not use markdown backticks around the JSON.
{{
  "title": "A short, engaging title",
  "summary": "A clean high-level summary paragraph. No markdown formatting like **bold**.",
  "key_points": ["Point 1 without markdown bullets", "Point 2", "Point 3"],
  "highlights": ["A notable quote or insight 1", "Insight 2"],
  "tone": "e.g., Informative, Persuasive, Technical",
  "confidence": 0.95,
  "reading_time": "e.g., 2 min read",
  "action_hint": "e.g., Good for a quick overview",
  "source_type": "{source_type}"
}}
"""

    # Attempt 1: Gemini
    try:
        summary_data = invoke_gemini_json(
            prompt=summarize_prompt,
            task_name="text_summarization",
            temperature=0.3,
        )
        if summary_data and "summary" in summary_data:
            return _normalize_summary(summary_data, text, source_type)
    except Exception as e:
        logger.warning(f"Gemini summarize error: {e}")

    # Attempt 2: Groq fallback
    logger.warning("Gemini summarize failed. Trying Groq fallback...")
    try:
        groq_messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": summarize_prompt},
        ]
        groq_data = invoke_groq_json(
            messages=groq_messages,
            task_name="text_summarization_groq",
            temperature=0.3,
        )
        if groq_data and "summary" in groq_data:
            return _normalize_summary(groq_data, text, source_type)
    except Exception as e:
        logger.warning(f"Groq summarize error: {e}")

    logger.error("All summarize model attempts failed. Returning local fallback.")
    return _fallback_summary(text, source_type)


def _normalize_summary(data: dict, original_text: str, source_type: str) -> dict:
    """Ensure all required SummaryResponse fields are present with sensible defaults.
    AI models sometimes return partial JSON; this prevents Pydantic validation errors."""
    cleaned = " ".join(original_text.split())
    preview = cleaned[:200] + ("..." if len(cleaned) > 200 else "")

    # Estimate reading time from word count
    word_count = len(cleaned.split())
    read_mins = max(1, round(word_count / 200))

    data.setdefault("title", "Summary")
    data.setdefault("summary", preview)
    data.setdefault("key_points", [])
    data.setdefault("highlights", [])
    data.setdefault("tone", "Informative")
    data.setdefault("confidence", 0.8)
    data.setdefault("reading_time", f"{read_mins} min read")
    data.setdefault("action_hint", "Quick overview")
    data.setdefault("source_type", source_type)

    # Ensure correct types for fields AI might return incorrectly
    if not isinstance(data["key_points"], list):
        data["key_points"] = [str(data["key_points"])]
    if not isinstance(data["highlights"], list):
        data["highlights"] = [str(data["highlights"])] if data["highlights"] else []
    if not isinstance(data["confidence"], (int, float)):
        try:
            data["confidence"] = float(data["confidence"])
        except (ValueError, TypeError):
            data["confidence"] = 0.8

    return data


def _fallback_summary(text: str, source_type: str) -> dict:
    cleaned = " ".join(text.split())
    preview = cleaned[:200]
    if len(cleaned) > 200:
        preview += "..."
    return {
        "title": "Basic Summary",
        "summary": preview or "No text provided.",
        "key_points": ["Backend AI is currently busy", "Here is a raw preview of the content"],
        "highlights": [],
        "tone": "Neutral",
        "confidence": 0.5,
        "reading_time": "1 min read",
        "action_hint": "Try again later for a full summary",
        "source_type": source_type
    }


# ============================================
# Easy Read (AI-powered accessible formatting)
# ============================================

async def easy_read_text(text: str, profile: str) -> dict:
    """
    Reformat text into a highly accessible 'Easy Read' format.
    Uses AI to create clear sections, bullet points, bold keywords,
    and simplified language tuned per neuro-profile.

    Returns:
        Dict with formatted_text, sections, word_count, reading_level, estimated_read_time
    """
    prompt_config = PROFILE_PROMPTS.get(profile, PROFILE_PROMPTS["ADHD"])
    system_prompt = prompt_config["system"]

    easy_read_prompt = f"""{system_prompt}

The user needs the following text reformatted for EASY READING.
Your goal is to make it maximally accessible for neurodivergent readers.

Rules:
1. Break the text into clear SHORT sections with descriptive headings
2. Use simple bullet points (not nested)
3. Bold the most important keywords by wrapping them in **double asterisks**
4. Use very short sentences (max 15 words each)
5. Replace jargon with everyday words
6. Add emoji icons before each section heading for visual anchoring
7. Each bullet should be ONE simple idea

TEXT TO REFORMAT:
\"\"\"
{text}
\"\"\"

Return ONLY valid JSON matching this schema exactly:
{{
  "formatted_text": "The full easy-read text as a single string with newlines. Use '📌 Heading' for sections and '  • bullet' for points.",
  "sections": [
    {{
      "heading": "Section Title with Emoji",
      "bullets": ["Simple point 1", "Simple point 2"]
    }}
  ],
  "word_count": 123,
  "reading_level": "simplified",
  "estimated_read_time": "2 min read"
}}
"""

    # Attempt 1: Gemini
    try:
        data = invoke_gemini_json(
            prompt=easy_read_prompt,
            task_name="easy_read_formatting",
            temperature=0.3,
        )
        if data and "formatted_text" in data:
            data.setdefault("sections", [])
            data.setdefault("word_count", len(text.split()))
            data.setdefault("reading_level", "simplified")
            data.setdefault("estimated_read_time", f"{max(1, len(text.split()) // 150)} min read")
            return data
    except Exception as e:
        logger.warning(f"Gemini easy-read failed: {e}")

    # Attempt 2: Groq fallback
    logger.warning("Gemini easy-read failed. Trying Groq fallback...")
    try:
        groq_messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": easy_read_prompt},
        ]
        groq_data = invoke_groq_json(
            messages=groq_messages,
            task_name="easy_read_formatting_groq",
            temperature=0.3,
        )
        if groq_data and "formatted_text" in groq_data:
            groq_data.setdefault("sections", [])
            groq_data.setdefault("word_count", len(text.split()))
            groq_data.setdefault("reading_level", "simplified")
            groq_data.setdefault("estimated_read_time", f"{max(1, len(text.split()) // 150)} min read")
            return groq_data
    except Exception as e:
        logger.warning(f"Groq easy-read failed: {e}")

    # Fallback: basic local formatting
    logger.error("All easy-read model attempts failed. Returning local fallback.")
    return _fallback_easy_read(text)


def _fallback_easy_read(text: str) -> dict:
    """Basic local easy-read formatting when AI is unavailable."""
    import re
    cleaned = " ".join(text.split())
    sentences = re.split(r'(?<=[.!?])\s+', cleaned)
    sentences = [s.strip() for s in sentences if s.strip()]

    sections = []
    current_bullets = []

    for s in sentences:
        if len(s) > 100:
            parts = [p.strip() for p in s.split(",") if p.strip()]
            current_bullets.extend(parts)
        else:
            current_bullets.append(s)

        if len(current_bullets) >= 4:
            sections.append({
                "heading": f"📌 Section {len(sections) + 1}",
                "bullets": current_bullets[:],
            })
            current_bullets = []

    if current_bullets:
        sections.append({
            "heading": f"📌 Section {len(sections) + 1}",
            "bullets": current_bullets,
        })

    if not sections:
        sections = [{"heading": "📌 Content", "bullets": [cleaned[:300] or "No content."]}]

    formatted_parts = []
    for sec in sections:
        formatted_parts.append(sec["heading"])
        for b in sec["bullets"]:
            formatted_parts.append(f"  • {b}")
        formatted_parts.append("")

    word_count = len(cleaned.split())
    return {
        "formatted_text": "\n".join(formatted_parts).strip(),
        "sections": sections,
        "word_count": word_count,
        "reading_level": "simplified",
        "estimated_read_time": f"{max(1, word_count // 150)} min read",
    }


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
