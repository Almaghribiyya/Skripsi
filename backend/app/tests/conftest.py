# konfigurasi pytest dan fixture yang dipakai bersama.
# fixture utama: test_client dengan mock service,
# supaya test bisa jalan tanpa qdrant, llm, atau firebase.

import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient

from app.config import Settings
from app.models.schemas import QueryResponse
from app.services.rag_service import RAGService


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    """Reset in-memory rate limiter storage sebelum tiap test.
    Slowapi Limiter di ask.py adalah singleton level modul,
    tanpa reset ini state-nya bocor antar test (terutama setelah test_rate_limiter)."""
    from app.routers.ask import limiter

    try:
        limiter._storage.reset()
    except Exception:
        pass
    yield


def get_test_settings() -> Settings:
    """Settings khusus untuk testing, auth dinonaktifkan."""
    return Settings(
        auth_enabled=False,
        gemini_api_key="test-key",
        qdrant_url="http://localhost:6333",
        similarity_threshold=0.80,
        rate_limit="100/minute",
        _env_file=None,
    )


@pytest.fixture()
def mock_rag_service():
    """RAGService palsu, tidak butuh Qdrant atau LLM aktif."""
    service = MagicMock(spec=RAGService)
    service.answer = AsyncMock(return_value=QueryResponse(
        status="success",
        pertanyaan="Apa itu hari pembalasan?",
        jawaban_llm="Hari pembalasan adalah hari kiamat...",
        referensi=[],
        skor_tertinggi=0.85,
    ))
    return service


@pytest.fixture()
def test_client(mock_rag_service):
    """TestClient dengan semua dependency di-mock.
    init_services() di-patch supaya lifespan tidak coba koneksi
    ke Qdrant atau LLM saat test jalan."""
    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: mock_rag_service
        app.dependency_overrides[get_settings] = get_test_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            yield client

        app.dependency_overrides.clear()
