"""
Unit Tests: Endpoint POST /api/ask.

Semua test menggunakan mock RAGService — tidak perlu Qdrant/LLM aktif.
Fokus: validasi request/response schema, error handling, rate limiting.
"""

from app.models.schemas import QueryResponse, ReferensiItem


def test_ask_returns_200_with_valid_payload(test_client):
    """POST /api/ask dengan payload valid harus mengembalikan 200."""
    payload = {"pertanyaan": "Apa itu hari pembalasan?", "top_k": 2}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "jawaban_llm" in data
    assert "referensi" in data
    assert "skor_tertinggi" in data


def test_ask_returns_422_without_pertanyaan(test_client):
    """POST /api/ask tanpa field 'pertanyaan' harus mengembalikan 422."""
    payload = {"top_k": 3}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422


def test_ask_returns_422_with_short_pertanyaan(test_client):
    """Pertanyaan kurang dari 3 karakter harus ditolak (min_length=3)."""
    payload = {"pertanyaan": "ab"}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422


def test_ask_returns_422_with_invalid_top_k(test_client):
    """top_k di luar range 1-5 harus ditolak."""
    payload = {"pertanyaan": "Apa itu taqwa?", "top_k": 10}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422


def test_ask_default_top_k_is_3(test_client, mock_rag_service):
    """Jika top_k tidak disertakan, default-nya harus 3."""
    payload = {"pertanyaan": "Apa itu taqwa?"}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 200
    # Cek bahwa rag_service.answer dipanggil dengan top_k=3
    mock_rag_service.answer.assert_called_once_with(
        pertanyaan="Apa itu taqwa?", top_k=3
    )


def test_ask_with_referensi(test_client, mock_rag_service):
    """Pastikan referensi ayat dikembalikan dengan benar."""
    mock_rag_service.answer.return_value = QueryResponse(
        status="success",
        pertanyaan="Apa itu sabar?",
        jawaban_llm="Sabar adalah...",
        referensi=[
            ReferensiItem(
                skor_kemiripan=0.89,
                surah="Al-Baqarah",
                ayat=153,
                teks_arab="يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",
                terjemahan="Wahai orang-orang yang beriman! Mohonlah pertolongan (kepada Allah) dengan sabar dan salat.",
            )
        ],
        skor_tertinggi=0.89,
    )
    payload = {"pertanyaan": "Apa itu sabar?"}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert len(data["referensi"]) == 1
    assert data["referensi"][0]["surah"] == "Al-Baqarah"
    assert data["referensi"][0]["ayat"] == 153
    assert data["skor_tertinggi"] == 0.89


def test_ask_empty_body_returns_422(test_client):
    """POST /api/ask dengan body kosong harus mengembalikan 422."""
    response = test_client.post("/api/ask", json={})
    assert response.status_code == 422


def test_rate_limiter(mock_rag_service):
    """Rate limiter harus mengembalikan 429 setelah melebihi batas 10/minute.

    Karena slowapi Limiter adalah singleton di level modul, state-nya
    bisa ter-akumulasi dari test sebelumnya. Test ini memverifikasi bahwa
    429 PASTI terjadi dalam 15 request (lebih dari cukup untuk limit 10/min).
    """
    from unittest.mock import patch
    from fastapi.testclient import TestClient
    from app.tests.conftest import get_test_settings

    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: mock_rag_service
        app.dependency_overrides[get_settings] = get_test_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            payload = {"pertanyaan": "Test rate limit"}
            got_429 = False

            for _ in range(15):
                res = client.post("/api/ask", json=payload)
                if res.status_code == 429:
                    got_429 = True
                    break

            assert got_429, "Rate limiter seharusnya mengembalikan 429 dalam 15 request"

        app.dependency_overrides.clear()
