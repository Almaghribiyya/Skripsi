# test untuk endpoint /api/ask dengan riwayat percakapan.
# pastikan endpoint menerima dan meneruskan riwayat ke rag_service.

import pytest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from app.models.schemas import QueryResponse
from app.services.rag_service import RAGService
from app.tests.conftest import get_test_settings


@pytest.fixture()
def _riwayat_client():
    """TestClient terpisah supaya tidak kena rate limit dari test lain."""
    mock_rag = MagicMock(spec=RAGService)
    mock_rag.answer.return_value = QueryResponse(
        status="success",
        pertanyaan="Test",
        jawaban_llm="Jawaban",
        referensi=[],
        skor_tertinggi=0.85,
    )

    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: mock_rag
        app.dependency_overrides[get_settings] = get_test_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            yield client, mock_rag

        app.dependency_overrides.clear()


def test_ask_with_riwayat_percakapan(_riwayat_client):
    """Endpoint harus meneruskan riwayat ke rag_service.answer()."""
    client, mock_rag = _riwayat_client
    payload = {
        "pertanyaan": "Jelaskan lebih lanjut",
        "riwayat_percakapan": [
            {"peran": "user", "konten": "Apa itu sabar?"},
            {"peran": "ai", "konten": "Sabar adalah menahan diri..."},
        ],
    }
    response = client.post("/api/ask", json=payload)
    assert response.status_code == 200

    # verifikasi rag_service.answer dipanggil dengan riwayat
    call_args = mock_rag.answer.call_args
    rp = call_args.kwargs.get("riwayat_percakapan") or call_args[1].get("riwayat_percakapan")
    assert rp is not None
    assert len(rp) == 2
    assert rp[0].peran == "user"
    assert rp[0].konten == "Apa itu sabar?"


def test_ask_without_riwayat_sends_none(_riwayat_client):
    """Tanpa riwayat, rag_service harus dapat None."""
    client, mock_rag = _riwayat_client
    payload = {"pertanyaan": "Apa itu iman?"}
    response = client.post("/api/ask", json=payload)
    assert response.status_code == 200

    call_args = mock_rag.answer.call_args
    rp = call_args.kwargs.get("riwayat_percakapan") or call_args[1].get("riwayat_percakapan")
    assert rp is None


def test_ask_with_empty_riwayat_sends_none(_riwayat_client):
    """Riwayat kosong ([]) harus diteruskan sebagai None."""
    client, mock_rag = _riwayat_client
    payload = {"pertanyaan": "Apa itu taqwa?", "riwayat_percakapan": []}
    response = client.post("/api/ask", json=payload)
    assert response.status_code == 200

    call_args = mock_rag.answer.call_args
    rp = call_args.kwargs.get("riwayat_percakapan") or call_args[1].get("riwayat_percakapan")
    assert rp is None


def test_ask_riwayat_invalid_schema_returns_422(test_client):
    """Riwayat dengan schema salah harus kena 422."""
    payload = {
        "pertanyaan": "Tes schema",
        "riwayat_percakapan": [
            {"role": "user", "content": "salah key"},  # key salah
        ],
    }
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422


def test_ask_riwayat_exceeds_max_returns_422(test_client):
    """Riwayat lebih dari 10 item harus kena 422."""
    riwayat = [{"peran": "user", "konten": f"Pesan {i}"} for i in range(11)]
    payload = {"pertanyaan": "Tes limit", "riwayat_percakapan": riwayat}
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422


def test_ask_riwayat_konten_too_long_returns_422(test_client):
    """Riwayat dengan konten > 2000 karakter harus kena 422."""
    payload = {
        "pertanyaan": "Tes konten panjang",
        "riwayat_percakapan": [
            {"peran": "user", "konten": "x" * 2001},
        ],
    }
    response = test_client.post("/api/ask", json=payload)
    assert response.status_code == 422
