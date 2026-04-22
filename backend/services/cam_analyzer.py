"""
NeuroRead AI — cam_analyzer.py
Module: Cognitive Accessibility Metric (CAM) Score
Analyzes page content to score its cognitive load.
Uses Groq with auto-model-rotation on rate limits.
"""

import logging
from typing import Dict, Any
from .llm_core import invoke_groq_json

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an expert accessibility evaluator for neurodivergent readers (ADHD, Dyslexia, Autism).
Evaluate the provided text and compute a Cognitive Accessibility Metric (CAM) score.
Consider:
1. Lexical complexity (long/academic words lower the score)
2. Sentence length (long run-on sentences lower the score)
3. Formatting density (large unbroken blocks of text lower the score)

Return strictly valid JSON with these exact keys:
- "score": Integer from 0 to 100 (100 = perfectly accessible, 0 = extremely dense)
- "rating": One of 'Excellent', 'Good', 'Fair', 'Poor'
- "insights": An array of exactly 2 brief, actionable insights (max 10 words each)
"""


def analyze_cam_score(text_content: str) -> Dict[str, Any]:
    """
    Evaluates the text content and returns a CAM score out of 100.
    """
    safe_text = text_content[:5000]
    if len(safe_text) < 50:
        return {
            "score": 100,
            "rating": "Excellent",
            "insights": ["Not enough text to analyze.", "Page looks accessible."]
        }

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Text to evaluate:\n{safe_text}"},
    ]

    result = invoke_groq_json(
        messages=messages,
        task_name="cam_analyzer",
        temperature=0.1,
    )

    if result:
        return result

    return {
        "score": 50,
        "rating": "Unknown",
        "insights": ["Failed to calculate CAM score.", "Try reloading the page."]
    }
