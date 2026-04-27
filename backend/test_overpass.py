import requests

overpass_url = "http://overpass-api.de/api/interpreter"
query = """
[out:json];
(
  node["amenity"="cafe"](around:3000,37.7749,-122.4194);
  node["amenity"="library"](around:3000,37.7749,-122.4194);
  node["leisure"="park"](around:3000,37.7749,-122.4194);
);
out 5;
"""
print("Querying overpass...")
res = requests.post(overpass_url, data={"data": query}, headers={"User-Agent": "NeuroSpace/1.0"})
print(res.status_code)
print(res.text[:500])
