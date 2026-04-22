"""
NeuroSpace — Voice Intent Parser
====================================
Parses voice transcriptions into actionable commands.
Uses Groq with auto-model-rotation on rate limits.
"""

import re
import logging
from .llm_core import invoke_groq_json

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are a strict command parser for the NeuroRead accessibility browser extension.

You MUST classify the user's voice command into ONE of the following categories and return EXACT JSON.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CATEGORY 1: feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return action_type "feature" with the EXACT feature_name from the list below.
Match the user's intent even if they use different words.

EXACT MAPPINGS (user phrase → feature_name):
- "simplify" / "simplify text" / "make it simpler" / "explain this" → "simplify"
- "format" / "formatting" / "change font" / "make it readable" / "fix the layout" → "formatting"
- "read" / "read aloud" / "read this" / "read it" / "speak" / "text to speech" / "read out" / "read the page" → "read"
- "stop" / "stop reading" / "be quiet" / "shut up" / "silence" / "pause" → "stop"
- "focus" / "focus mode" / "true focus" / "hide distractions" / "clean the page" / "reader mode" → "focus"
- "ruler" / "reading ruler" / "read ruler" / "line guide" / "focus line" → "ruler"
- "toc" / "table of contents" / "contents" / "show menu" / "navigation" → "toc"
- "undo" / "reset" / "revert" / "go back" / "turn off" / "deactivate" / "remove all" → "undo"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CATEGORY 2: dom_manipulation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return action_type "dom_manipulation" with a dom_action dict.
Use this for scrolling, navigation, or clicking page elements.

EXACT MAPPINGS:
- "scroll down" / "go down" / "page down" → {"method": "scrollBy", "selector": null, "args": {"top": 500, "behavior": "smooth"}}
- "scroll up" / "go up" / "page up" → {"method": "scrollBy", "selector": null, "args": {"top": -500, "behavior": "smooth"}}
- "go to top" / "top of page" / "beginning" → {"method": "scrollTo", "selector": null, "args": {"top": 0, "behavior": "smooth"}}
- "go to bottom" / "bottom" / "end of page" → {"method": "scrollTo", "selector": null, "args": {"top": 99999, "behavior": "smooth"}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CATEGORY 3: speak
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ONLY use this if the request is truly impossible for a browser extension.
Fill speak_message with a short, friendly rejection.

IMPORTANT RULES:
- NEVER return "speak" for commands that match categories 1 or 2.
- When in doubt between "feature" and "speak", ALWAYS choose "feature".
- When in doubt between "dom_manipulation" and "speak", ALWAYS choose "dom_manipulation".

Return JSON with these keys:
- "action_type": one of "feature", "dom_manipulation", "speak"
- "feature_name": string or null
- "dom_action": object or null
- "speak_message": string or null
"""


def parse_intent(transcription: str) -> dict:
    transcription = re.sub(r'[^\w\s]$', '', transcription.strip())

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f'The user said: "{transcription}"'},
    ]

    response = invoke_groq_json(
        messages=messages,
        task_name="voice_intent",
        temperature=0.1,
    )

    if response:
        return response

    return {
        "action_type": "speak",
        "speak_message": "Sorry, I couldn't process that command right now."
    }
