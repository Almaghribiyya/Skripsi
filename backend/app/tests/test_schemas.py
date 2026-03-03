# test untuk validasi schema Pydantic — request dan response.
# pastikan constraints (min_length, max_length, ge, le) berfungsi.

import pytest
from pydantic import ValidationError
from app.models.schemas import (
    QueryRequest,
    QueryResponse,
    ReferensiItem,
    RiwayatItem,
    ErrorResponse,
    HealthResponse,
)


# ── QueryRequest ─────────────────────────────────────────────

class TestQueryRequest:
    def test_valid_request(self):
        req = QueryRequest(pertanyaan="Apa itu iman?")
        assert req.pertanyaan == "Apa itu iman?"
        assert req.top_k == 3  # default
        assert req.riwayat_percakapan == []  # default

    def test_min_length_pertanyaan(self):
        with pytest.raises(ValidationError):
            QueryRequest(pertanyaan="ab")  # < 3 karakter

    def test_max_length_pertanyaan(self):
        with pytest.raises(ValidationError):
            QueryRequest(pertanyaan="x" * 501)  # > 500 karakter

    def test_top_k_range_valid(self):
        for k in [1, 2, 3, 4, 5]:
            req = QueryRequest(pertanyaan="Test", top_k=k)
            assert req.top_k == k

    def test_top_k_below_min(self):
        with pytest.raises(ValidationError):
            QueryRequest(pertanyaan="Test", top_k=0)

    def test_top_k_above_max(self):
        with pytest.raises(ValidationError):
            QueryRequest(pertanyaan="Test", top_k=6)

    def test_riwayat_percakapan_valid(self):
        riwayat = [
            RiwayatItem(peran="user", konten="Halo"),
            RiwayatItem(peran="ai", konten="Halo juga"),
        ]
        req = QueryRequest(pertanyaan="Test", riwayat_percakapan=riwayat)
        assert len(req.riwayat_percakapan) == 2

    def test_riwayat_max_length(self):
        """Riwayat percakapan maksimal 10 item."""
        riwayat = [
            RiwayatItem(peran="user", konten=f"Pesan {i}") for i in range(11)
        ]
        with pytest.raises(ValidationError):
            QueryRequest(pertanyaan="Test", riwayat_percakapan=riwayat)


# ── RiwayatItem ──────────────────────────────────────────────

class TestRiwayatItem:
    def test_valid_user_role(self):
        item = RiwayatItem(peran="user", konten="Apa itu sabar?")
        assert item.peran == "user"

    def test_valid_ai_role(self):
        item = RiwayatItem(peran="ai", konten="Sabar adalah...")
        assert item.peran == "ai"

    def test_konten_max_length(self):
        with pytest.raises(ValidationError):
            RiwayatItem(peran="user", konten="x" * 2001)  # > 2000

    def test_konten_required(self):
        with pytest.raises(ValidationError):
            RiwayatItem(peran="user")  # konten wajib


# ── QueryResponse ────────────────────────────────────────────

class TestQueryResponse:
    def test_full_response(self):
        resp = QueryResponse(
            status="success",
            pertanyaan="Apa itu taqwa?",
            jawaban_llm="Taqwa adalah...",
            referensi=[
                ReferensiItem(
                    skor_kemiripan=0.92,
                    surah="Al-Baqarah",
                    ayat=197,
                    teks_arab="وَتَزَوَّدُوا",
                    terjemahan="Dan berbekallah...",
                )
            ],
            skor_tertinggi=0.92,
        )
        assert resp.status == "success"
        assert len(resp.referensi) == 1

    def test_empty_referensi_default(self):
        resp = QueryResponse(
            pertanyaan="Test", jawaban_llm="Test", skor_tertinggi=0.0
        )
        assert resp.referensi == []
        assert resp.status == "success"  # default


# ── ErrorResponse & HealthResponse ───────────────────────────

class TestErrorResponse:
    def test_error_response(self):
        err = ErrorResponse(message="Terjadi kesalahan")
        assert err.status == "error"
        assert err.message == "Terjadi kesalahan"


class TestHealthResponse:
    def test_health_response(self):
        health = HealthResponse(status="ok", message="Running", version="1.0.0")
        assert health.status == "ok"
