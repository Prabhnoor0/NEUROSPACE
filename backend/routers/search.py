"""
NeuroSpace — Search Router
==============================
Aggregates search results from Wikipedia and DuckDuckGo.
Returns combined results for the Flutter search screen.
"""

import logging
import httpx
from fastapi import APIRouter, Query
from typing import Optional

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================
# Combined Search Endpoint
# ============================================

@router.get("/search")
async def search(
    q: str = Query(..., description="Search query"),
    limit: Optional[int] = Query(8, description="Max results per source"),
):
    """
    Search Wikipedia and DuckDuckGo for the given query.
    Returns combined results from both sources.
    """
    wikipedia_results = []
    duckduckgo_results = []
    featured = None

    async with httpx.AsyncClient(timeout=10.0) as client:
        # ── Wikipedia Search ──
        try:
            wiki_resp = await client.get(
                "https://en.wikipedia.org/w/api.php",
                params={
                    "action": "query",
                    "list": "search",
                    "srsearch": q,
                    "srlimit": limit,
                    "format": "json",
                    "origin": "*",
                },
            )
            if wiki_resp.status_code == 200:
                data = wiki_resp.json()
                for item in data.get("query", {}).get("search", []):
                    # Clean HTML from snippet
                    snippet = item.get("snippet", "")
                    import re
                    snippet = re.sub(r"<[^>]+>", "", snippet)
                    snippet = snippet.replace("&quot;", '"').replace("&amp;", "&")

                    title = item.get("title", "")
                    wikipedia_results.append({
                        "title": title,
                        "snippet": snippet,
                        "url": f"https://en.wikipedia.org/wiki/{title.replace(' ', '_')}",
                        "source": "wikipedia",
                        "pageId": item.get("pageid"),
                    })
        except Exception as e:
            logger.warning(f"Wikipedia search failed: {e}")

        # ── Wikipedia Featured Summary (top result) ──
        if wikipedia_results:
            try:
                top_title = wikipedia_results[0]["title"].replace(" ", "_")
                summary_resp = await client.get(
                    f"https://en.wikipedia.org/api/rest_v1/page/summary/{top_title}",
                    headers={"Accept": "application/json"},
                )
                if summary_resp.status_code == 200:
                    sdata = summary_resp.json()
                    featured = {
                        "title": sdata.get("title", ""),
                        "extract": sdata.get("extract", ""),
                        "thumbnail": sdata.get("thumbnail", {}).get("source"),
                        "url": sdata.get("content_urls", {}).get("desktop", {}).get("page", ""),
                    }
            except Exception as e:
                logger.warning(f"Wikipedia summary failed: {e}")

        # ── DuckDuckGo Instant Answer ──
        try:
            ddg_resp = await client.get(
                "https://api.duckduckgo.com/",
                params={
                    "q": q,
                    "format": "json",
                    "no_html": "1",
                    "skip_disambig": "1",
                },
            )
            if ddg_resp.status_code == 200:
                data = ddg_resp.json()

                # Abstract
                abstract_text = data.get("AbstractText", "")
                if abstract_text:
                    duckduckgo_results.append({
                        "title": data.get("Heading", q),
                        "snippet": abstract_text,
                        "url": data.get("AbstractURL", ""),
                        "source": "duckduckgo",
                        "thumbnail": data.get("Image") if data.get("Image") else None,
                    })

                # Related topics
                for topic in data.get("RelatedTopics", [])[:5]:
                    if isinstance(topic, dict) and topic.get("Text"):
                        duckduckgo_results.append({
                            "title": topic.get("Text", "")[:80],
                            "snippet": topic.get("Text", ""),
                            "url": topic.get("FirstURL", ""),
                            "source": "duckduckgo",
                        })
        except Exception as e:
            logger.warning(f"DuckDuckGo search failed: {e}")

    return {
        "query": q,
        "featured": featured,
        "wikipedia": wikipedia_results,
        "web": duckduckgo_results,
        "total": len(wikipedia_results) + len(duckduckgo_results),
    }
