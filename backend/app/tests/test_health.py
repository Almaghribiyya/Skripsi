"""
Unit Tests: Health Check endpoints.

Test ini TIDAK membutuhkan Qdrant/LLM aktif — menggunakan mock fixtures.
"""


def test_root_returns_200(test_client):
    """GET / harus mengembalikan status ok dan pesan selamat datang."""
    response = test_client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "running" in data["message"].lower() or "Qur'an" in data["message"]
    assert "version" in data


def test_root_contains_version(test_client):
    """GET / harus menyertakan versi aplikasi."""
    response = test_client.get("/")
    data = response.json()
    assert data["version"]  # Non-empty version string
