"""
NeuroRead AI — tone_analyzer.py
Module: Content Tone & Emotion Analysis
Uses Groq with auto-model-rotation on rate limits.
"""

import logging
from typing import Dict, Any
from .llm_core import invoke_groq_json

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an expert reading assistant for adults on the autism spectrum.
Your job is to read the selected text and explicitly define the social, emotional, and pragmatic subtext.
Neurodivergent readers sometimes miss implicit meaning, sarcasm, or unstated intent. 

Read the text and parse out:
1. The primary emotional tone.
2. The intensity of that emotion.
3. The true implicit meaning (translate literal words into what the author is *actually* trying to communicate or accomplish).

Output strictly valid JSON with these exact keys:
- "primary_tone": The dominant tone (e.g., 'Sarcastic', 'Informative', 'Persuasive', 'Hostile', 'Encouraging', 'Satirical')
- "emotional_intensity": One of 'Low', 'Medium', 'High'
- "implicit_meaning": A 1-2 sentence plain-language explanation of what the author actually means
"""


def analyze_tone(text_content: str) -> Dict[str, Any]:
    """
    Evaluates text and provides a breakdown of its tone, emotion, and implicit meaning.
    """
    safe_text = text_content[:3000].strip()
    if len(safe_text) < 10:
        return {
            "primary_tone": "Neutral",
            "emotional_intensity": "Low",
            "implicit_meaning": "Not enough text selected to analyze tone."
        }

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Text to evaluate:\n{safe_text}"},
    ]

    result = invoke_groq_json(
        messages=messages,
        task_name="tone_analyzer",
        temperature=0.2,
    )

    if result:
        return result

    return {
        "primary_tone": "Unknown",
        "emotional_intensity": "Low",
        "implicit_meaning": "Failed to analyze text. Please try selecting a different paragraph."
    }
