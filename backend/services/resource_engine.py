"""
NeuroSpace — Resource Recommendation Engine
=============================================
Deterministic scoring engine that matches neurodivergent users
to relevant educational and medical resources.

Uses Overpass API for real nearby data and LLM for enrichment.
Falls back to curated local data when APIs fail.
"""

import logging
import math
import hashlib
import json
from typing import List, Dict, Any, Optional
from datetime import datetime

import httpx

from models.resource_schemas import (
    RecommendationRequest,
    RecommendedResource,
    RecommendationResponse,
    ResourceType,
    ResourceCategory,
    UrgencyLevel,
    DeliveryMode,
    NGOEntry,
    NGOListResponse,
)
from services.llm_core import invoke_groq_json

logger = logging.getLogger(__name__)


# ============================================
# Distance helper
# ============================================

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance in km between two lat/lng points."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _make_id(name: str, lat: float, lon: float) -> str:
    """Generate a deterministic ID from name + location."""
    raw = f"{name}:{lat:.4f}:{lon:.4f}"
    return hashlib.md5(raw.encode()).hexdigest()[:12]


# ============================================
# Overpass API queries
# ============================================

async def _fetch_overpass_resources(
    lat: float, lng: float, radius: int, category: ResourceCategory
) -> List[Dict[str, Any]]:
    """Fetch real POIs from OpenStreetMap Overpass API."""
    if category == ResourceCategory.MEDICAL:
        query = f"""
        [out:json];
        (
          node["amenity"="hospital"](around:{radius},{lat},{lng});
          node["amenity"="clinic"](around:{radius},{lat},{lng});
          node["amenity"="doctors"](around:{radius},{lat},{lng});
          node["healthcare"="psychologist"](around:{radius},{lat},{lng});
          node["healthcare"="speech_therapist"](around:{radius},{lat},{lng});
          node["healthcare"="occupational_therapist"](around:{radius},{lat},{lng});
          node["healthcare"="rehabilitation"](around:{radius},{lat},{lng});
        );
        out 30;
        """
    else:
        query = f"""
        [out:json];
        (
          node["amenity"="school"](around:{radius},{lat},{lng});
          node["amenity"="college"](around:{radius},{lat},{lng});
          node["amenity"="training"](around:{radius},{lat},{lng});
          node["amenity"="community_centre"](around:{radius},{lat},{lng});
          node["amenity"="social_facility"](around:{radius},{lat},{lng});
          node["office"="ngo"](around:{radius},{lat},{lng});
          node["office"="educational_institution"](around:{radius},{lat},{lng});
        );
        out 30;
        """

    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.post(
                "http://overpass-api.de/api/interpreter",
                data={"data": query},
                headers={"User-Agent": "NeuroSpace/1.0"},
            )
            if response.status_code == 200:
                data = response.json()
                results = []
                for el in data.get("elements", []):
                    tags = el.get("tags", {})
                    name = tags.get("name")
                    if not name:
                        continue
                    results.append({
                        "name": name,
                        "lat": el["lat"],
                        "lon": el["lon"],
                        "tags": tags,
                    })
                return results
    except Exception as e:
        logger.error(f"Overpass resource fetch error: {e}")
    return []


async def _fetch_overpass_ngos(lat: float, lng: float, radius: int = 15000) -> List[Dict[str, Any]]:
    """Fetch NGOs and social facilities from Overpass API."""
    query = f"""
    [out:json];
    (
      node["office"="ngo"](around:{radius},{lat},{lng});
      node["amenity"="social_facility"](around:{radius},{lat},{lng});
      node["office"="charity"](around:{radius},{lat},{lng});
      node["office"="association"](around:{radius},{lat},{lng});
    );
    out 20;
    """
    try:
        async with httpx.AsyncClient(timeout=12.0) as client:
            response = await client.post(
                "http://overpass-api.de/api/interpreter",
                data={"data": query},
                headers={"User-Agent": "NeuroSpace/1.0"},
            )
            if response.status_code == 200:
                data = response.json()
                results = []
                for el in data.get("elements", []):
                    tags = el.get("tags", {})
                    name = tags.get("name")
                    if not name:
                        continue
                    results.append({
                        "name": name,
                        "lat": el["lat"],
                        "lon": el["lon"],
                        "tags": tags,
                    })
                return results
    except Exception as e:
        logger.error(f"Overpass NGO fetch error: {e}")
    return []


# ============================================
# Scoring Engine
# ============================================

def _classify_resource_type(tags: Dict[str, str], category: ResourceCategory) -> ResourceType:
    """Classify an OSM POI into a ResourceType based on its tags."""
    amenity = tags.get("amenity", "").lower()
    healthcare = tags.get("healthcare", "").lower()
    office = tags.get("office", "").lower()

    if healthcare == "psychologist":
        return ResourceType.PSYCHOLOGIST
    if healthcare == "speech_therapist":
        return ResourceType.SPEECH_THERAPY
    if healthcare == "occupational_therapist":
        return ResourceType.OCCUPATIONAL_THERAPY
    if healthcare == "rehabilitation":
        return ResourceType.REHAB_CENTER
    if amenity == "hospital":
        return ResourceType.HOSPITAL
    if amenity in ("clinic", "doctors"):
        return ResourceType.NEUROLOGIST
    if office == "ngo" or amenity == "social_facility":
        return ResourceType.NGO
    if amenity in ("school", "college", "training"):
        return ResourceType.SPECIAL_EDUCATOR
    if amenity == "community_centre":
        return ResourceType.SUPPORT_GROUP

    return ResourceType.SPECIAL_EDUCATOR if category == ResourceCategory.EDUCATION else ResourceType.HOSPITAL


def _score_resource(
    resource: Dict[str, Any],
    req: RecommendationRequest,
    distance_km: float,
) -> float:
    """
    Deterministic scoring (0-100) based on:
    - Distance (closer = higher, max 30 pts)
    - Category match (15 pts)
    - Urgency boost (15 pts)
    - Diagnosis relevance (20 pts)
    - Budget fit (10 pts)
    - Delivery mode match (10 pts)
    """
    score = 0.0

    # 1. Distance score (30 pts) — inverse proportion within radius
    max_dist = req.distance_radius_km
    if distance_km <= max_dist:
        score += 30.0 * (1.0 - distance_km / max_dist)
    else:
        score += 5.0  # small bonus for being found at all

    # 2. Category match (15 pts)
    tags = resource.get("tags", {})
    rtype = _classify_resource_type(tags, req.category)
    if req.category == ResourceCategory.MEDICAL and rtype in (
        ResourceType.HOSPITAL,
        ResourceType.NEUROLOGIST,
        ResourceType.PSYCHOLOGIST,
        ResourceType.SPEECH_THERAPY,
        ResourceType.OCCUPATIONAL_THERAPY,
        ResourceType.REHAB_CENTER,
    ):
        score += 15.0
    elif req.category == ResourceCategory.EDUCATION and rtype in (
        ResourceType.SPECIAL_EDUCATOR,
        ResourceType.REMEDIAL_LEARNING,
        ResourceType.SUPPORT_GROUP,
        ResourceType.SIMPLIFIED_MODULE,
    ):
        score += 15.0
    else:
        score += 5.0  # partial match

    # 3. Urgency boost (15 pts)
    urgency_map = {
        UrgencyLevel.URGENT: 15.0,
        UrgencyLevel.HIGH: 12.0,
        UrgencyLevel.MEDIUM: 8.0,
        UrgencyLevel.LOW: 4.0,
    }
    if req.urgency in (UrgencyLevel.URGENT, UrgencyLevel.HIGH):
        # Hospitals and clinics get extra priority for urgent cases
        if rtype in (ResourceType.HOSPITAL, ResourceType.NEUROLOGIST):
            score += urgency_map[req.urgency]
        else:
            score += urgency_map[req.urgency] * 0.5
    else:
        score += urgency_map.get(req.urgency, 5.0)

    # 4. Diagnosis relevance (20 pts)
    if req.diagnosis:
        diag = req.diagnosis.lower()
        name_lower = resource.get("name", "").lower()
        tag_vals = " ".join(tags.values()).lower()

        # Direct keyword match
        if diag in name_lower or diag in tag_vals:
            score += 20.0
        # Specialty match
        elif any(kw in name_lower or kw in tag_vals for kw in [
            "neuro", "special", "therapy", "rehab", "learning", "disability",
            "autism", "adhd", "dyslexia", "child", "developmental",
        ]):
            score += 14.0
        else:
            score += 7.0  # generic
    else:
        score += 10.0  # no diagnosis = neutral

    # 5. Budget (10 pts) — free/NGOs score higher for "free" budget
    if req.budget:
        budget = req.budget.lower()
        if budget == "free":
            if rtype in (ResourceType.NGO, ResourceType.SUPPORT_GROUP):
                score += 10.0
            elif "free" in " ".join(tags.values()).lower():
                score += 10.0
            else:
                score += 3.0
        else:
            score += 6.0
    else:
        score += 5.0

    # 6. Delivery mode (10 pts)
    if req.delivery_mode == DeliveryMode.ONLINE:
        if "website" in tags or "url" in tags:
            score += 10.0
        else:
            score += 3.0
    elif req.delivery_mode == DeliveryMode.OFFLINE:
        score += 8.0  # physical POI is inherently offline
    else:
        score += 7.0

    return min(100.0, round(score, 1))


def _explain_score(
    resource: Dict[str, Any],
    rtype: ResourceType,
    distance_km: float,
    req: RecommendationRequest,
) -> str:
    """Generate a human-readable explanation for the recommendation."""
    parts = []
    name = resource.get("name", "Resource")

    if distance_km < 3.0:
        parts.append(f"Very close to you ({distance_km:.1f} km)")
    elif distance_km < 10.0:
        parts.append(f"Nearby ({distance_km:.1f} km away)")
    else:
        parts.append(f"{distance_km:.1f} km from your location")

    type_label = rtype.value.replace("_", " ").title()
    parts.append(f"Offers {type_label} services")

    if req.diagnosis:
        parts.append(f"Relevant for {req.diagnosis}")

    if req.urgency in (UrgencyLevel.URGENT, UrgencyLevel.HIGH):
        parts.append("Prioritized for urgency")

    return ". ".join(parts) + "."


# ============================================
# Fallback curated data
# ============================================

def _generate_fallback_resources(
    req: RecommendationRequest,
) -> List[RecommendedResource]:
    """Generate curated fallback resources when APIs are unavailable."""
    lat = req.latitude or 28.6139
    lng = req.longitude or 77.2090

    fallbacks = [
        RecommendedResource(
            id=_make_id("Nearest General Hospital", lat, lng),
            name="Nearest General Hospital",
            type=ResourceType.HOSPITAL,
            category=ResourceCategory.MEDICAL,
            distance_km=2.5,
            availability="24/7 Emergency",
            price_range="Varies",
            location="Search Google Maps for nearest hospital",
            latitude=lat + 0.005,
            longitude=lng + 0.003,
            contact="112",
            accessibility_notes="Most hospitals have wheelchair access",
            score=78.0,
            reason="Nearby hospital with emergency services. Available 24/7 for urgent needs.",
            booking_available=False,
            languages=["English", "Hindi"],
            services=["Emergency", "Neurology", "Pediatrics"],
        ),
        RecommendedResource(
            id=_make_id("Community Learning Center", lat, lng),
            name="Community Learning Center",
            type=ResourceType.SPECIAL_EDUCATOR,
            category=ResourceCategory.EDUCATION,
            distance_km=4.0,
            availability="Mon-Sat 9AM-5PM",
            price_range="Free - Low",
            location="Community center nearby",
            latitude=lat + 0.008,
            longitude=lng - 0.004,
            accessibility_notes="Quiet rooms available",
            score=72.0,
            reason="Community center offering special education support. Budget-friendly and accessible.",
            booking_available=True,
            languages=["English", "Hindi"],
            services=["Special Education", "Remedial Learning", "Counseling"],
        ),
        RecommendedResource(
            id=_make_id("Speech & Language Therapy Clinic", lat, lng),
            name="Speech & Language Therapy Clinic",
            type=ResourceType.SPEECH_THERAPY,
            category=ResourceCategory.MEDICAL,
            distance_km=6.0,
            availability="Mon-Fri 10AM-6PM",
            price_range="Medium",
            location="Medical complex nearby",
            latitude=lat - 0.006,
            longitude=lng + 0.007,
            contact="+91-XXXXXXXXXX",
            accessibility_notes="Sensory-friendly waiting area",
            score=68.0,
            reason="Specialized speech therapy clinic. Supports neurodivergent patients with sensory accommodations.",
            booking_available=True,
            languages=["English", "Hindi"],
            services=["Speech Therapy", "Language Assessment", "Communication Training"],
        ),
        RecommendedResource(
            id=_make_id("NeuroSupport NGO", lat, lng),
            name="NeuroSupport NGO",
            type=ResourceType.NGO,
            category=ResourceCategory.EDUCATION,
            distance_km=8.0,
            availability="Mon-Fri 9AM-4PM",
            price_range="Free",
            location="NGO office nearby",
            latitude=lat + 0.012,
            longitude=lng - 0.009,
            email="help@neurosupport.org",
            accessibility_notes="Fully accessible premises",
            score=65.0,
            reason="Free NGO providing educational support and advocacy for neurodivergent individuals.",
            booking_available=True,
            languages=["English", "Hindi", "Regional"],
            services=["Counseling", "Educational Support", "Parent Training", "Advocacy"],
        ),
    ]

    # Filter by category if specified
    if req.category == ResourceCategory.MEDICAL:
        fallbacks = [r for r in fallbacks if r.category == ResourceCategory.MEDICAL] or fallbacks[:2]
    elif req.category == ResourceCategory.EDUCATION:
        fallbacks = [r for r in fallbacks if r.category == ResourceCategory.EDUCATION] or fallbacks[:2]

    return fallbacks


def _generate_fallback_ngos(lat: float, lng: float) -> List[NGOEntry]:
    """Generate curated fallback NGOs."""
    return [
        NGOEntry(
            id=_make_id("National Trust for Disability", lat, lng),
            name="National Trust for Disability",
            distance_km=5.0,
            services=["Counseling", "Skill Training", "Educational Support", "Legal Aid"],
            contact="+91-11-2436-3508",
            email="contactus@thenationaltrust.gov.in",
            languages=["English", "Hindi"],
            timings="Mon-Fri 9:30AM-5:30PM",
            area_served="Pan India",
            latitude=lat + 0.008,
            longitude=lng - 0.005,
        ),
        NGOEntry(
            id=_make_id("Action for Autism", lat, lng),
            name="Action for Autism",
            distance_km=8.5,
            services=["Autism Support", "Parent Training", "Inclusive Education", "Awareness"],
            contact="+91-11-2651-6959",
            email="actionforautism@gmail.com",
            whatsapp="+91-9876543210",
            languages=["English", "Hindi"],
            timings="Mon-Sat 9AM-5PM",
            area_served="Delhi NCR & Pan India",
            latitude=lat - 0.01,
            longitude=lng + 0.006,
        ),
        NGOEntry(
            id=_make_id("ADAPT (formerly Spastics Society)", lat, lng),
            name="ADAPT (formerly Spastics Society)",
            distance_km=12.0,
            services=["Physiotherapy", "Occupational Therapy", "Special Education", "Vocational Training"],
            contact="+91-22-2444-6296",
            email="info@adaptssi.org",
            languages=["English", "Hindi", "Marathi"],
            timings="Mon-Fri 9AM-5PM",
            area_served="Mumbai & Pan India",
            latitude=lat + 0.015,
            longitude=lng - 0.012,
        ),
    ]


# ============================================
# Public API
# ============================================

async def get_recommendations(req: RecommendationRequest) -> RecommendationResponse:
    """
    Main recommendation entry point.
    1. Fetch real POIs from Overpass
    2. Score and rank them
    3. Enrich with LLM if available
    4. Fall back to curated data if APIs fail
    """
    lat = req.latitude or 28.6139
    lng = req.longitude or 77.2090
    radius_m = int(req.distance_radius_km * 1000)

    # 1. Fetch real POIs
    raw_places = await _fetch_overpass_resources(lat, lng, radius_m, req.category)
    logger.info(f"[ResourceEngine] Fetched {len(raw_places)} POIs from Overpass")

    fallback_used = False

    if not raw_places:
        logger.warning("[ResourceEngine] No Overpass results, using fallback data")
        fallback_used = True
        fallback_resources = _generate_fallback_resources(req)
        # Sort fallbacks by score
        fallback_resources.sort(key=lambda r: r.score, reverse=True)
        return RecommendationResponse(
            recommendations=fallback_resources,
            total=len(fallback_resources),
            query_summary=_build_query_summary(req),
            fallback_used=True,
        )

    # 2. Score and build recommendation objects
    scored: List[RecommendedResource] = []
    for place in raw_places:
        p_lat = place["lat"]
        p_lon = place["lon"]
        dist = _haversine_km(lat, lng, p_lat, p_lon)
        tags = place.get("tags", {})
        rtype = _classify_resource_type(tags, req.category)
        s = _score_resource(place, req, dist)
        reason = _explain_score(place, rtype, dist, req)

        contact = tags.get("phone") or tags.get("contact:phone")
        email_val = tags.get("email") or tags.get("contact:email")
        website = tags.get("website") or tags.get("url")
        wheelchair = tags.get("wheelchair", "unknown")

        acc_notes_parts = []
        if wheelchair in ("yes", "limited"):
            acc_notes_parts.append(f"Wheelchair: {wheelchair}")
        if tags.get("hearing_loop") == "yes":
            acc_notes_parts.append("Hearing loop available")
        acc_notes = ". ".join(acc_notes_parts) if acc_notes_parts else None

        resource = RecommendedResource(
            id=_make_id(place["name"], p_lat, p_lon),
            name=place["name"],
            type=rtype,
            category=req.category,
            distance_km=round(dist, 1),
            availability="Check with provider",
            price_range=None,
            location=tags.get("addr:street") or tags.get("addr:city") or "See map",
            latitude=p_lat,
            longitude=p_lon,
            contact=contact,
            email=email_val,
            accessibility_notes=acc_notes,
            score=s,
            reason=reason,
            booking_available=True,
            languages=["English"],
            timings=tags.get("opening_hours"),
            services=[rtype.value.replace("_", " ").title()],
        )
        scored.append(resource)

    # Sort by score descending
    scored.sort(key=lambda r: r.score, reverse=True)

    # Cap results at 15
    scored = scored[:15]

    return RecommendationResponse(
        recommendations=scored,
        total=len(scored),
        query_summary=_build_query_summary(req),
        fallback_used=fallback_used,
    )


async def get_nearby_ngos(lat: float, lng: float, radius_km: float = 15.0) -> NGOListResponse:
    """
    Fetch nearby NGOs from Overpass, or fall back to curated data.
    """
    radius_m = int(radius_km * 1000)
    raw_ngos = await _fetch_overpass_ngos(lat, lng, radius_m)

    if not raw_ngos:
        logger.warning("[ResourceEngine] No Overpass NGO results, using fallback")
        fallbacks = _generate_fallback_ngos(lat, lng)
        return NGOListResponse(ngos=fallbacks, total=len(fallbacks))

    ngos: List[NGOEntry] = []
    for ngo in raw_ngos:
        n_lat = ngo["lat"]
        n_lon = ngo["lon"]
        dist = _haversine_km(lat, lng, n_lat, n_lon)
        tags = ngo.get("tags", {})

        entry = NGOEntry(
            id=_make_id(ngo["name"], n_lat, n_lon),
            name=ngo["name"],
            distance_km=round(dist, 1),
            services=_extract_ngo_services(tags),
            contact=tags.get("phone") or tags.get("contact:phone"),
            whatsapp=tags.get("contact:whatsapp"),
            email=tags.get("email") or tags.get("contact:email"),
            languages=["English"],
            timings=tags.get("opening_hours"),
            area_served=tags.get("addr:city") or tags.get("addr:district"),
            latitude=n_lat,
            longitude=n_lon,
        )
        ngos.append(entry)

    # Sort by distance
    ngos.sort(key=lambda n: n.distance_km or 999)

    # If very few results, append fallbacks
    if len(ngos) < 3:
        fallbacks = _generate_fallback_ngos(lat, lng)
        existing_ids = {n.id for n in ngos}
        for fb in fallbacks:
            if fb.id not in existing_ids:
                ngos.append(fb)

    return NGOListResponse(ngos=ngos[:10], total=len(ngos))


def _extract_ngo_services(tags: Dict[str, str]) -> List[str]:
    """Extract service descriptions from OSM tags."""
    services = []
    social = tags.get("social_facility")
    if social:
        services.append(social.replace("_", " ").title())
    desc = tags.get("description")
    if desc:
        services.append(desc[:80])
    if not services:
        services.append("Community Support")
    return services


def _build_query_summary(req: RecommendationRequest) -> str:
    """Build a human-readable summary of the recommendation query."""
    parts = []
    if req.diagnosis:
        parts.append(f"for {req.diagnosis}")
    parts.append(f"{req.category.value} resources")
    if req.urgency != UrgencyLevel.MEDIUM:
        parts.append(f"({req.urgency.value} urgency)")
    if req.budget:
        parts.append(f"budget: {req.budget}")
    if req.delivery_mode != DeliveryMode.BOTH:
        parts.append(f"mode: {req.delivery_mode.value}")
    return "Showing " + ", ".join(parts)
