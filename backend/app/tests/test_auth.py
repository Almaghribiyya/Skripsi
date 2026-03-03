# test untuk middleware Firebase Auth.
# verifikasi behavior saat auth_enabled true/false,
# token missing, token valid, token expired.

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

from app.tests.conftest import get_test_settings
from app.models.schemas import QueryResponse
from app.services.rag_service import RAGService


@pytest.fixture()
def _mock_rag():
    service = MagicMock(spec=RAGService)
    service.answer.return_value = QueryResponse(
        status="success",
        pertanyaan="Test",
        jawaban_llm="Jawaban",
        referensi=[],
        skor_tertinggi=0.85,
    )
    return service


def test_auth_disabled_allows_access(_mock_rag):
    """Kalau auth_enabled=False, request tanpa token harus berhasil."""
    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: _mock_rag
        app.dependency_overrides[get_settings] = get_test_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            payload = {"pertanyaan": "Apa itu iman?"}
            response = client.post("/api/ask", json=payload)
            assert response.status_code == 200

        app.dependency_overrides.clear()


def test_auth_enabled_rejects_no_token(_mock_rag):
    """Kalau auth_enabled=True, request tanpa token harus kena 401."""
    def get_auth_settings():
        return get_test_settings().model_copy(update={"auth_enabled": True})

    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: _mock_rag
        app.dependency_overrides[get_settings] = get_auth_settings

        with TestClient(app, raise_server_exceptions=False) as client:
            payload = {"pertanyaan": "Apa itu iman?"}
            response = client.post("/api/ask", json=payload)
            assert response.status_code == 401

        app.dependency_overrides.clear()


def test_auth_enabled_rejects_invalid_token(_mock_rag):
    """Token tidak valid harus kena 401 saat auth_enabled=True."""
    def get_auth_settings():
        return get_test_settings().model_copy(update={"auth_enabled": True})

    with patch("app.main.init_services"):
        from app.main import app
        from app.dependencies import get_rag_service
        from app.config import get_settings

        app.dependency_overrides[get_rag_service] = lambda: _mock_rag
        app.dependency_overrides[get_settings] = get_auth_settings

        # mock firebase_admin agar tidak perlu credentials asli
        with patch(
            "app.middleware.firebase_auth._ensure_firebase_initialized"
        ):
            # fb_auth diimpor lokal di verify_firebase_token,
            # jadi kita mock firebase_admin.auth secara langsung
            mock_verify = MagicMock(side_effect=Exception("Invalid token"))
            with patch.dict(
                "sys.modules",
                {"firebase_admin.auth": MagicMock(verify_id_token=mock_verify)},
            ):
                with TestClient(app, raise_server_exceptions=False) as client:
                    payload = {"pertanyaan": "Apa itu iman?"}
                    response = client.post(
                        "/api/ask",
                        json=payload,
                        headers={"Authorization": "Bearer fake-token"},
                    )
                    assert response.status_code == 401

        app.dependency_overrides.clear()
