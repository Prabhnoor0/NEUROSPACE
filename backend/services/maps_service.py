import httpx
import json
import logging
from typing import List, Dict, Any
from services.llm_core import invoke_groq_json

logger = logging.getLogger(__name__)

async def get_quiet_spaces(lat: float, lng: float, radius: int = 3000) -> List[Dict[str, Any]]:
    """
    Fetch real places from OpenStreetMap (Overpass API) and use Groq to curate 
    them with sensory-friendly profiles for neurodivergent individuals.
    """
    # 1. Fetch real nearby locations from Overpass API
    overpass_url = "http://overpass-api.de/api/interpreter"
    query = f"""
    [out:json];
    (
      node["amenity"="cafe"](around:{radius},{lat},{lng});
      node["amenity"="library"](around:{radius},{lat},{lng});
      node["leisure"="park"](around:{radius},{lat},{lng});
    );
    out 20;
    """
    
    real_places = []
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                overpass_url, 
                data={"data": query},
                headers={"User-Agent": "NeuroSpace/1.0"}
            )
            if response.status_code == 200:
                data = response.json()
                for element in data.get("elements", []):
                    tags = element.get("tags", {})
                    # Only keep elements with names
                    if "name" in tags:
                        category = "Park"
                        if tags.get("amenity") == "cafe": category = "Cafe"
                        if tags.get("amenity") == "library": category = "Library"
                        
                        real_places.append({
                            "name": tags["name"],
                            "lat": element["lat"],
                            "lon": element["lon"],
                            "category": category
                        })
    except Exception as e:
        logger.error(f"Overpass API error: {e}")
        
    # Slice to max 5 places to not overwhelm LLM
    real_places = real_places[:5]
    
    # Fallback if no local places found
    if not real_places:
        real_places = [
            {"name": "Mindful Corner (Simulated)", "lat": lat + 0.001, "lon": lng + 0.001, "category": "Sanctuary"}
        ]

    # 2. Use Groq to build sensory profiles
    system_prompt = (
        "You are an accessibility expert matching neurodivergent users with quiet places. "
        "I will provide a list of REAL places near the user. You must return a JSON object "
        "with a single key 'places' containing an array of objects profiling THEM. "
        "Do not invent new places, only use the ones provided. "
        "Invent reasonable estimates for the sensory fields."
    )
    
    places_str = json.dumps(real_places, indent=2)
    user_prompt = f"""
Here are the real places:
{places_str}

Return a JSON object with key "places" containing an array, where each object has:
- "name": (string, exactly as provided)
- "category": (string, exactly as provided)
- "location": {{"lat": float, "lng": float}} (use the lat/lon values provided)
- "crowd": (string, e.g. "Low", "Moderate", "Very Low")
- "lighting": (string, e.g. "Dim / Natural", "Warm Ambient", "Bright / Sunlit")
- "noise": (string, e.g. "Silent", "White Noise", "Soft Music / Low Chatter")
- "image_icon": (string, one of: "library", "park", "cafe", "spa")

Example output format:
{{"places": [{{"name": "Example Cafe", "category": "Cafe", "location": {{"lat": 37.78, "lng": -122.41}}, "crowd": "Low", "lighting": "Warm Ambient", "noise": "Soft Music", "image_icon": "cafe"}}]}}
"""
    
    try:
        curated_data = invoke_groq_json(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            task_name="curate_quiet_spaces",
            temperature=0.5
        )
        
        logger.info(f"Groq maps response type: {type(curated_data)}, data: {json.dumps(curated_data)[:300] if curated_data else 'None'}")
        
        if curated_data:
            # Handle dict with a key containing the array
            if isinstance(curated_data, dict):
                # Try common keys
                for key in ['places', 'quiet_spaces', 'results', 'data']:
                    if key in curated_data and isinstance(curated_data[key], list):
                        return curated_data[key]
                # If dict has only one key and it's a list, use that
                if len(curated_data) == 1:
                    val = list(curated_data.values())[0]
                    if isinstance(val, list):
                        return val
            elif isinstance(curated_data, list):
                return curated_data
            
    except Exception as e:
        logger.error(f"Groq formatting error for maps: {e}", exc_info=True)
        
    # Fallback if Groq completely fails
    logger.warning("Using fallback sensory profiles (Groq curation failed)")
    return [
        {
            "name": p["name"],
            "category": p["category"],
            "location": {"lat": p["lat"], "lng": p["lon"]},
            "crowd": "Low" if p["category"] == "Library" else "Moderate",
            "lighting": "Dim / Natural" if p["category"] == "Library" else "Warm Ambient",
            "noise": "Silent" if p["category"] == "Library" else "Soft Background",
            "image_icon": "park" if p["category"] == "Park" else ("library" if p["category"] == "Library" else "cafe")
        } for p in real_places
    ]
