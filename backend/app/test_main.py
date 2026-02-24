import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/")
    assert response.status_code == 200
    assert "Quran RAG Backend is running" in response.json()["message"]

def test_ask_endpoint_integration():
    payload = {
        "pertanyaan": "Apa itu hari pembalasan?",
        "top_k": 2
    }
    # Pastikan header menggunakan IP spesifik agar tidak terkena imbas limit global
    response = client.post("/api/ask", json=payload, headers={"X-Forwarded-For": "192.168.1.1"})
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "jawaban_llm" in data
    assert isinstance(data["referensi"], list)

def test_ask_endpoint_validation_error():
    payload = {"top_k": 3}
    response = client.post("/api/ask", json=payload, headers={"X-Forwarded-For": "192.168.1.2"})
    assert response.status_code == 422 # Pydantic menolak karena tidak ada 'pertanyaan'

def test_rate_limiter():
    payload = {"pertanyaan": "Test limit"}
    headers = {"X-Forwarded-For": "10.0.0.1"} # Gunakan IP buatan khusus untuk test ini
    
    for _ in range(10):
        res = client.post("/api/ask", json=payload, headers=headers)
        # Jika Qdrant atau LLM mati, statusnya tetap 200 karena ada mekanisme Fallback.
        # Yang kita pedulikan adalah dia belum diblokir (bukan 429).
        assert res.status_code in [200, 500] 
        
    response_blocked = client.post("/api/ask", json=payload, headers=headers)
    assert response_blocked.status_code == 429
    assert "Rate limit exceeded" in response_blocked.text