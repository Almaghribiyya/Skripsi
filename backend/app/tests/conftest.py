"""
Pytest configuration dan shared fixtures.

Fixture utama:
  - `test_client`: TestClient dengan service yang di-mock.
  - `mock_rag_service`: RAGService palsu untuk unit testing.
"""

import pytest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from app.config import Settings
from app.models.schemas import QueryResponse
from app.services.rag_service import RAGService


def get_test_settings() -> Settings:
    """Settings khusus untuk testing (auth dinonaktifkan)."""
    return Settings(
        auth_enabled=False,
        gemini_api_key="test-key",
        qdrant_url="http://localhost:6333",
        similarity_threshold=0.45,
        rate_limit="100/minute",
        _env_file=None,
    )


@pytest.fixture()
def mock_rag_service():
    """RAGService yang di-mock — tidak membutuhkan Qdrant/LLM aktif."""
    service = MagicMock(spec=RAGService)
    service.answer.return_value = QueryResponse(
        status="success",
        pertanyaan="Apa itu hari pembalasan?",
        jawaban_llm="Hari pembalasan adalah hari kiamat...",
        referensi=[],
        skor_tertinggi=0.85,
    )
    return service


@pytest.fixture()
def test_client(mock_rag_service):
    """
    TestClient dengan semua dependency yang di-mock.
    TIDAK membutuhkan Qdrant, LLM, atau Firebase yang aktif.

    init_services() di-patch agar lifespan tidak mencoba koneksi
    ke Qdrant/LLM saat test berjalan.
    """
    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: mock_rag_service
        app.dependency_overrides[get_settings] = get_test_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            yield client

        app.dependency_overrides.clear()
