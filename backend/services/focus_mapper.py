"""
NeuroSpace — Focus Mapper
============================
Generates CSS selectors for Reader Mode isolation.
Uses Groq with auto-model-rotation on rate limits.
"""

import logging
from .llm_core import invoke_groq_json

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are an expert Frontend DOM Analyzer specializing in accessibility and Reader Mode isolation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TASK: Reader Mode Isolation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Given the HTML skeleton below, you must identify:
1. The unique selector for the MAIN content/article area.
2. A broad set of selectors targeting EVERY distracting peripheral element.

REQUIREMENTS:
- For `hide_selectors`, aggressively select: `<nav>`, `<footer>`, `<aside>`, `.sidebar`, `#vector-toc`, cookie banners, social bars, ad slots, and site headers.
- If you see classes like `mw-panel`, `vector-toc-container`, `vector-pinnable-header`, `menu`, or `nav`, include them in `hide_selectors`.
- DO NOT hide the main content container or its direct ancestors.
- DO NOT hide elements inside the main content container.
- CRITICAL: NEVER include the main body containers in `hide_selectors`!

Return strictly valid JSON with these exact keys:
- "main_content_selector": CSS selector for the primary article container
- "hide_selectors": Comma-separated CSS selectors for everything else to hide
"""


def generate_focus_map(html_skeleton: str) -> dict:
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"HTML SKELETON:\n{html_skeleton}"},
    ]

    response = invoke_groq_json(
        messages=messages,
        task_name="focus_mapper",
        temperature=0.1,
    )

    if response:
        return response

    logger.warning("[Focus Mapper] All retries failed. Using hardcoded fallback.")
    return {
        "main_content_selector": "article, main, .mw-parser-output, [role='main']",
        "hide_selectors": "nav, footer, aside, .sidebar, .menu, #vector-toc, .vector-toc-container, .mw-panel, [class*='cookie'], [class*='ad-']"
    }
