"""
NeuroSpace — Image Scan & Simplification Router
=================================================
Accepts a photo upload, uses Groq Vision to extract text,
then simplifies and summarizes it for neurodivergent readers.
"""

import logging
import json
from fastapi import APIRouter, UploadFile, File, HTTPException, Query
from typing import Optional

from services.llm_core import invoke_groq_vision, invoke_groq_json

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Scan Image Endpoint
# ============================================

@router.post("/scan-image")
async def scan_image(
    image: UploadFile = File(...),
    profile: Optional[str] = Query("ADHD", description="Neuro-profile: ADHD, Dyslexia, or Autism"),
):
    """
    Upload a photo of text (menu, textbook, whiteboard, etc.).
    Returns:
      - extracted_text: raw OCR result
      - summary: 2-3 sentence plain-English summary
      - simplified: bullet-point simplification
      - key_terms: important vocabulary with definitions
    """
    # Validate file type
    if image.content_type and not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image (JPEG, PNG, etc.)")

    # Read image bytes
    image_bytes = await image.read()
    if len(image_bytes) < 100:
        raise HTTPException(status_code=400, detail="Image file is too small or empty.")

    logger.info(f"Scan request: {image.filename}, size={len(image_bytes)} bytes, profile={profile}")

    # ── Step 1: Extract text via Groq Vision ──
    ocr_prompt = (
        "You are an expert OCR system. Look at this image carefully and extract ALL the text you can see. "
        "Preserve the original structure (headings, paragraphs, lists) as much as possible. "
        "If there are diagrams or figures, describe them briefly in [brackets]. "
        "Return ONLY the extracted text, nothing else."
    )

    extracted_text = invoke_groq_vision(
        image_bytes=image_bytes,
        prompt=ocr_prompt,
        task_name="scan_ocr",
    )

    if not extracted_text:
        raise HTTPException(
            status_code=502,
            detail="Could not extract text from the image. Please try a clearer photo."
        )

    logger.info(f"OCR extracted {len(extracted_text)} characters")

    # ── Step 2: Simplify & summarize via Groq Text ──
    profile_instructions = {
        "ADHD": (
            "The reader has ADHD. Use short punchy sentences. "
            "Add emoji markers for key points. Break everything into tiny chunks. "
            "Highlight the most important takeaway FIRST."
        ),
        "Dyslexia": (
            "The reader has dyslexia. Use simple, common words. "
            "Avoid long or complex vocabulary. Keep sentences under 12 words. "
            "Use numbered lists instead of paragraphs."
        ),
        "Autism": (
            "The reader is autistic. Be literal and precise — avoid idioms, metaphors, or sarcasm. "
            "Use clear, structured formatting with labeled sections. "
            "Define any ambiguous terms explicitly."
        ),
    }

    profile_note = profile_instructions.get(profile, profile_instructions["ADHD"])

    simplify_messages = [
        {
            "role": "system",
            "content": (
                "You are a text accessibility expert. You take raw text and make it easy to understand. "
                f"{profile_note} "
                "Return a JSON object with these keys:\n"
                '- "summary": A 2-3 sentence plain-English summary of the entire text.\n'
                '- "simplified": The full text rewritten in simplified, accessible bullet points (use markdown).\n'
                '- "key_terms": An array of objects [{\"term\": \"...\", \"definition\": \"...\"}] for important vocabulary.\n'
            ),
        },
        {
            "role": "user",
            "content": f"Here is the extracted text to simplify:\n\n---\n{extracted_text}\n---\n\nReturn valid JSON only.",
        },
    ]

    simplified_data = invoke_groq_json(
        messages=simplify_messages,
        task_name="scan_simplify",
        temperature=0.3,
    )

    if simplified_data and isinstance(simplified_data, dict):
        return {
            "status": "success",
            "extracted_text": extracted_text,
            "summary": simplified_data.get("summary", ""),
            "simplified": simplified_data.get("simplified", ""),
            "key_terms": simplified_data.get("key_terms", []),
            "profile": profile,
        }

    # Fallback if Groq text fails but OCR succeeded
    return {
        "status": "partial",
        "extracted_text": extracted_text,
        "summary": "AI summarization temporarily unavailable.",
        "simplified": extracted_text,
        "key_terms": [],
        "profile": profile,
    }
