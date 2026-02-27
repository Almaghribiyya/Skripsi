# test untuk endpoint health check.
# tidak butuh Qdrant atau LLM aktif, pakai mock fixtures.


def test_root_returns_200(test_client):
    """GET / harus kembalikan status ok dan pesan selamat datang."""
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
    assert data["version"]  # harus non-empty
