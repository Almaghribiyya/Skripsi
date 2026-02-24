import pytest
from fastapi.testclient import TestClient
from app.main import app

# Menggunakan TestClient dari FastAPI untuk simulasi server
client = TestClient(app)

def test_health_check():
    """Unit Test: Memastikan server menyala dan merespons root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    assert "Quran RAG Backend is running" in response.json()["message"]

def test_ask_endpoint_integration():
    """Integration Test: Memastikan alur RAG (Pencarian -> LLM -> Respons JSON) berjalan normal"""
    payload = {
        "pertanyaan": "Apa itu hari pembalasan?",
        "top_k": 2
    }
    response = client.post("/api/ask", json=payload)
    
    # Harus merespons dengan status 200 OK
    assert response.status_code == 200
    
    data = response.json()
    # Memastikan format data sesuai dengan skema QueryResponse
    assert data["status"] == "success"
    assert "jawaban_llm" in data
    assert isinstance(data["referensi"], list)

def test_ask_endpoint_validation_error():
    """Unit Test (Error Handling): Memastikan sistem menolak payload yang cacat (tanpa pertanyaan)"""
    payload = {
        "top_k": 3
    }
    response = client.post("/api/ask", json=payload)
    
    # Harus merespons dengan status 422 Unprocessable Entity karena field 'pertanyaan' hilang
    assert response.status_code == 422

def test_rate_limiter():
    """Unit Test (Keamanan): Memastikan Rate Limiter memblokir spam request"""
    payload = {"pertanyaan": "Test limit"}
    
    # Tembak API sebanyak 11 kali (karena batas di main.py adalah 10/minute)
    for _ in range(10):
        client.post("/api/ask", json=payload)
        
    # Tembakan ke-11 harus diblokir
    response_blocked = client.post("/api/ask", json=payload)
    
    # HTTP 429 adalah status standar untuk "Too Many Requests"
    assert response_blocked.status_code == 429
    assert "Rate limit exceeded" in response_blocked.text