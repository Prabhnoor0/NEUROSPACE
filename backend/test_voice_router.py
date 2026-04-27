from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def test_voice_intent_fallback_summarize():
    response = client.post(
        "/api/voice/intent",
        json={"transcription": "summarize this"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["action_type"] in {"feature", "speak"}
    assert "normalized_command" in body


def test_voice_intent_validation_error_for_empty():
    response = client.post(
        "/api/voice/intent",
        json={"transcription": ""},
    )

    assert response.status_code == 422
