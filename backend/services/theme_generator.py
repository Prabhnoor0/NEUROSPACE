"""
NeuroSpace — AI Theme Generator
==================================
Uses Groq LLM to dynamically generate optimal theme/typography settings
based on user-selected neurodivergent traits. No more hardcoded presets!

The AI considers accessibility research, cognitive load theory, and
sensory processing to generate custom font, color, spacing, and
interaction parameters tailored to each user's unique trait combination.
"""

import json
import logging
from typing import List

from .llm_core import invoke_groq_with_fallback

logger = logging.getLogger(__name__)

THEME_SYSTEM_PROMPT = """You are a neurodivergent accessibility expert and UI/UX designer. 
Your job is to generate optimal app theme settings for a user based on their selected traits.

You MUST return ONLY valid JSON with these exact keys (no markdown, no explanation):

{
  "profileType": "adhd" | "dyslexia" | "autism" | "custom",
  "fontFamily": "<one of: Inter, Lexend, OpenDyslexic, Atkinson Hyperlegible, IBM Plex Sans, Roboto Mono>",
  "fontSize": <number 14-22>,
  "letterSpacing": <number 0.0-2.5>,
  "lineHeight": <number 1.3-2.5>,
  "backgroundColor": "<hex color>",
  "textColor": "<hex color>",
  "accentColor": "<hex color>",
  "cardColor": "<hex color>",
  "definitionColor": "<hex color>",
  "exampleColor": "<hex color>",
  "ttsSpeed": <number 0.7-1.3>,
  "contrastMode": "high" | "normal" | "low",
  "focusBordersEnabled": true | false,
  "reasoning": "<1-2 sentence explanation of your choices>"
}

Guidelines based on research:
- ADHD: Use engaging accent colors (warm tones), enable focus borders, slightly faster TTS (1.05-1.15), moderate font size, Inter or Lexend font
- Dyslexia: Use OpenDyslexic or Lexend font, LARGE letter spacing (1.2-2.5), high line height (1.8-2.5), warm background (cream/pale yellow), high contrast, larger font (18-22)
- Autism/Sensory: Use calming cool tones (blues/teals), LOW contrast to reduce sensory overload, muted colors, structured fonts like IBM Plex Sans or Lexend, slower TTS (0.85-0.95)
- Bright light sensitivity: Dark backgrounds with muted text, avoid pure white, use low contrast mode
- Combined traits: Blend the settings intelligently — e.g. ADHD+Dyslexia should use OpenDyslexic with focus borders and warm colors
- All dark mode backgrounds should be in the 0x0F-0x1A range for hex, never pure black
- Card colors should be slightly lighter than background
- Definition and example colors should be distinct but harmonious with the palette
"""


async def generate_theme(traits: List[str], energy_level: str = "medium") -> dict:
    """
    Generate an AI-powered theme configuration based on user traits.

    Args:
        traits: List of trait keys like ["lose_focus", "dense_text", "bright_lights", "literal_explanations"]
        energy_level: "high", "medium", or "low" — affects color vibrancy

    Returns:
        Dict with all theme parameters
    """
    trait_descriptions = {
        "lose_focus": "I lose focus easily (ADHD-related attention difficulties)",
        "dense_text": "Dense text makes me dizzy (Dyslexia-related reading difficulties)",
        "bright_lights": "Bright lights hurt my eyes (sensory sensitivity / photophobia)",
        "literal_explanations": "I need literal explanations (autism-related preference for structured, concrete information)",
    }

    # Build the user prompt
    trait_list = "\n".join([
        f"- {trait_descriptions.get(t, t)}"
        for t in traits
    ])

    user_prompt = f"""Generate optimal app theme settings for a user with these traits:

{trait_list}

Energy level: {energy_level} ({"vibrant, engaging colors" if energy_level == "high" else "balanced, moderate colors" if energy_level == "medium" else "calm, muted colors"})

Return ONLY the JSON object, no other text."""

    try:
        messages = [
            {"role": "system", "content": THEME_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ]

        response = invoke_groq_with_fallback(
            messages=messages,
            task_name="theme_generation",
            temperature=0.3,  # Low temp for consistent, research-backed outputs
        )

        if not response:
            return _get_fallback_theme(traits)

        # Strip any markdown code fences if present
        cleaned = response.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]  # Remove first line
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            cleaned = cleaned.strip()

        theme_data = json.loads(cleaned)

        # Validate required keys exist
        required_keys = [
            "profileType", "fontFamily", "fontSize", "letterSpacing",
            "lineHeight", "backgroundColor", "textColor", "accentColor",
            "cardColor", "ttsSpeed", "contrastMode", "focusBordersEnabled",
        ]
        for key in required_keys:
            if key not in theme_data:
                raise ValueError(f"Missing required key: {key}")

        # Ensure numeric values are in valid ranges
        theme_data["fontSize"] = max(14, min(22, float(theme_data["fontSize"])))
        theme_data["letterSpacing"] = max(0.0, min(2.5, float(theme_data["letterSpacing"])))
        theme_data["lineHeight"] = max(1.3, min(2.5, float(theme_data["lineHeight"])))
        theme_data["ttsSpeed"] = max(0.7, min(1.3, float(theme_data["ttsSpeed"])))

        # Ensure colors are valid hex
        for color_key in ["backgroundColor", "textColor", "accentColor", "cardColor", "definitionColor", "exampleColor"]:
            if color_key in theme_data:
                color = theme_data[color_key]
                if not color.startswith("#"):
                    color = f"#{color}"
                theme_data[color_key] = color

        # Fill in defaults for optional colors
        if "definitionColor" not in theme_data:
            theme_data["definitionColor"] = theme_data["cardColor"]
        if "exampleColor" not in theme_data:
            theme_data["exampleColor"] = theme_data["cardColor"]

        logger.info(f"AI theme generated: {theme_data.get('profileType')} — {theme_data.get('reasoning', 'no reasoning')}")
        return theme_data

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse AI theme response: {e}")
        # Return a sensible default
        return _get_fallback_theme(traits)
    except Exception as e:
        logger.error(f"Theme generation failed: {e}")
        return _get_fallback_theme(traits)


def _get_fallback_theme(traits: List[str]) -> dict:
    """Return a reasonable fallback theme if AI fails."""
    # Pick the most dominant trait
    if "dense_text" in traits:
        return {
            "profileType": "dyslexia",
            "fontFamily": "OpenDyslexic",
            "fontSize": 18.0,
            "letterSpacing": 1.5,
            "lineHeight": 2.0,
            "backgroundColor": "#FFF9C4",
            "textColor": "#1A1A1A",
            "accentColor": "#1565C0",
            "cardColor": "#FFF3E0",
            "definitionColor": "#BBDEFB",
            "exampleColor": "#C8E6C9",
            "ttsSpeed": 1.0,
            "contrastMode": "high",
            "focusBordersEnabled": False,
            "reasoning": "Fallback: Dyslexia-optimized preset",
        }
    elif "bright_lights" in traits or "literal_explanations" in traits:
        return {
            "profileType": "autism",
            "fontFamily": "Lexend",
            "fontSize": 16.0,
            "letterSpacing": 0.5,
            "lineHeight": 1.8,
            "backgroundColor": "#1A2332",
            "textColor": "#CCD6E0",
            "accentColor": "#5B9BD5",
            "cardColor": "#243447",
            "definitionColor": "#1E3A5F",
            "exampleColor": "#2E4A3A",
            "ttsSpeed": 0.9,
            "contrastMode": "low",
            "focusBordersEnabled": False,
            "reasoning": "Fallback: Autism-optimized preset",
        }
    else:
        return {
            "profileType": "adhd",
            "fontFamily": "Inter",
            "fontSize": 17.0,
            "letterSpacing": 0.3,
            "lineHeight": 1.6,
            "backgroundColor": "#0F0F1A",
            "textColor": "#F5F5F5",
            "accentColor": "#FF6B6B",
            "cardColor": "#1A1A2E",
            "definitionColor": "#2D1B69",
            "exampleColor": "#1B4332",
            "ttsSpeed": 1.1,
            "contrastMode": "normal",
            "focusBordersEnabled": True,
            "reasoning": "Fallback: ADHD-optimized preset",
        }
