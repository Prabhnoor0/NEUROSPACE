"""
NeuroSpace — Focus Reader
============================
Extracts and restructures web content for cognitive accessibility.
Uses Groq with auto-model-rotation on rate limits.
"""

import json
import logging
from typing import List, Dict, Optional
from .llm_core import invoke_groq_json

logger = logging.getLogger(__name__)


# ============================================
# Article Extraction
# ============================================

ARTICLE_SYSTEM_PROMPT = """You are an expert in cognitive accessibility and content extraction.
Your task is to take the provided raw scraped text from a web page and distill it into a clean,
sectioned, point-by-point structural format.

RULES:
1. IDENTIFY MAIN CONTENT: Ignore navigation links, cookie banners, and footer boilerplate.
2. EXTRACT TITLE: Find the primary headline of the article.
3. ORGANIZE INTO SECTIONS: Group the content into logical sections. Each section MUST have a short
   descriptive heading and a list of concise bullet points underneath.
4. COGNITIVE ACCESSIBILITY: Keep sentences concise. Split dense paragraphs into multiple points.
5. CLEANUP: Do not include generic UI text like "Share this", "Read more", "Comments".
6. MINIMUM SECTIONS: Always produce at least 2-3 sections.

Return strictly valid JSON with these exact keys:
- "title": The main article title
- "sections": Array of objects, each with "heading" (string) and "points" (array of strings)
"""

FEED_SYSTEM_PROMPT = """You are an expert in cognitive accessibility and content curation.
You will receive a JSON string containing raw "card candidates" from a web page.

RULES:
1. FILTER JUNK: Discard ads, promotional content, tiny icons, navigation links.
2. SELECT VALID ARTICLES: Only keep genuine news articles, blog posts, or content pieces.
3. REWRITE/SIMPLIFY: Rewrite long titles and create simplified summaries.
4. COGNITIVE ACCESSIBILITY: Keep summaries to 1-2 very short sentences. Use plain language.

Return strictly valid JSON with this exact key:
- "feed": Array of objects, each with "title", "link", "image_url", and "summary"
"""


def extract_article(raw_text: str):
    if not raw_text or len(raw_text.strip()) < 50:
        return {"title": "Not enough content", "sections": []}

    truncated_text = raw_text[:5000]

    messages = [
        {"role": "system", "content": ARTICLE_SYSTEM_PROMPT},
        {"role": "user", "content": f"INPUT TEXT:\n{truncated_text}"},
    ]

    res = invoke_groq_json(
        messages=messages,
        task_name="focus_reader_article",
        temperature=0.1,
    )

    return res if res else {"title": "Not enough content", "sections": []}


def extract_feed(feed_items: List[Dict[str, str]]):
    if not feed_items or len(feed_items) == 0:
        return {"feed": []}

    candidates = feed_items[:8]
    feed_json_str = json.dumps(candidates)

    messages = [
        {"role": "system", "content": FEED_SYSTEM_PROMPT},
        {"role": "user", "content": f"RAW CARD CANDIDATES:\n{feed_json_str}"},
    ]

    res = invoke_groq_json(
        messages=messages,
        task_name="focus_reader_feed",
        temperature=0.1,
    )

    return res if res else {"feed": []}


def extract_reader_content(
    raw_text: Optional[str] = None,
    feed_items: Optional[List[Dict[str, str]]] = None,
    is_feed: bool = False,
):
    result = {"title": "Focus Reader", "sections": [], "feed": []}

    if raw_text and len(raw_text.strip()) > 300:
        a_res = extract_article(raw_text)
        if a_res and a_res.get("sections"):
            result["title"] = a_res.get("title", "Article Summary")
            result["sections"] = a_res.get("sections", [])

    if feed_items and len(feed_items) >= 4:
        f_res = extract_feed(feed_items)
        if f_res and f_res.get("feed"):
            result["feed"] = f_res.get("feed", [])

    return result
