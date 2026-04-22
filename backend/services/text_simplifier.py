"""
NeuroSpace — Text Simplifier (Gemini-powered)
================================================
Simplifies text chunks using the Gemini API.
Switched from Groq/LangChain to Gemini for higher-quality simplification.
Uses GeminiModelPool for auto-fallback on rate limits.
"""

import json
import logging
from typing import List
from .llm_core import invoke_gemini_json

logger = logging.getLogger(__name__)


def simplify_text_chunks(chunks: List[str]) -> List[str]:
    """Takes a list of text strings and uses Gemini to simplify them."""
    if not chunks:
        return []

    formatted_chunks = "\n---\n".join(
        [f"CHUNK {i}:\n{chunk}" for i, chunk in enumerate(chunks)]
    )

    prompt = f"""You are an expert in cognitive accessibility, specifically writing for ADHD and Autism.
Your task is to simplify the provided text chunks to an 'Explain Like I'm 5' (ELI5) level.

RULES FOR SIMPLIFICATION:
1. USE EXTREMELY SIMPLE LANGUAGE. If a word has more than 3 syllables, try to find a simpler one.
2. AGGRESSIVE BREVITY: Reduce the word count by at least 40-50%.
3. REMOVE ALL JARGON: Replace technical terms with easy-to-understand analogies or descriptions.
4. ONE IDEA PER SENTENCE: Split every sentence that contains 'and', 'but', or 'which' into two short sentences.
5. NO FILLER: Start directly with the simplified content.
6. TARGET AUDIENCE: Write as if you are explaining this to a 10-year-old with short attention span.
7. FORMAT AS BULLETS: Return the simplified text as a concise markdown bulleted list.

INPUT CHUNKS:
{formatted_chunks}

IMPORTANT: Return JSON with a "simplified_chunks" array that has the EXACT same number of items ({len(chunks)}) as input chunks.
Each simplified chunk corresponds to the input chunk at the same index.

Return ONLY valid JSON: {{"simplified_chunks": ["chunk1", "chunk2", ...]}}
"""

    response = invoke_gemini_json(
        prompt=prompt,
        task_name="text_simplifier",
        temperature=0.3,
    )

    if response:
        simplified = response.get("simplified_chunks", [])
        if isinstance(simplified, list):
            # Ensure same length as input
            if len(simplified) != len(chunks):
                while len(simplified) < len(chunks):
                    simplified.append(chunks[len(simplified)])
                simplified = simplified[:len(chunks)]
            return simplified

    logger.warning("[text_simplifier] Gemini simplification failed, returning original chunks.")
    return chunks
