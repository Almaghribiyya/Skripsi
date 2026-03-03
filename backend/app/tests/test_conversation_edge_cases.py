# integration test — validasi kualitas referensi dan edge cases.
# BUKAN unit test: test ini kirim request HTTP asli ke http://localhost:8000.
#
# prasyarat: sama seperti test_conversation_integration.py

import time
import requests
import pytest

BASE_URL = "http://localhost:8000"
ASK_URL = f"{BASE_URL}/api/ask"
HEALTH_URL = f"{BASE_URL}/"
TIMEOUT = 60


@pytest.fixture(scope="module", autouse=True)
def check_backend_running():
    """Pastikan backend Docker sudah hidup sebelum test dimulai."""
    try:
        resp = requests.get(HEALTH_URL, timeout=5)
        assert resp.status_code == 200, f"Health check gagal: {resp.status_code}"
    except requests.ConnectionError:
        pytest.skip(
            "Backend tidak berjalan di localhost:8000. "
            "Jalankan 'docker compose up --build -d' terlebih dahulu."
        )


def _ask(pertanyaan: str, *, top_k: int = 3, riwayat=None) -> dict:
    """Helper: kirim pertanyaan ke /api/ask dan kembalikan response JSON."""
    payload = {"pertanyaan": pertanyaan, "top_k": top_k}
    if riwayat:
        payload["riwayat_percakapan"] = riwayat
    resp = requests.post(ASK_URL, json=payload, timeout=TIMEOUT)
    assert resp.status_code == 200, (
        f"Expected 200, got {resp.status_code}: {resp.text}"
    )
    return resp.json()


# ═══════════════════════════════════════════════════════
#  VALIDASI KUALITAS REFERENSI
# ═══════════════════════════════════════════════════════


class TestReferenceQuality:
    """Verifikasi bahwa referensi ayat memiliki struktur lengkap."""

    def test_referensi_memiliki_teks_arab_dan_terjemahan(self):
        """Setiap referensi harus punya teks Arab dan terjemahan."""
        data = _ask("Jelaskan tentang hari kiamat dalam Al-Quran")

        assert data["status"] == "success"
        for i, ref in enumerate(data["referensi"]):
            assert ref.get("teks_arab"), f"Referensi {i} tidak ada teks Arab"
            assert ref.get("terjemahan"), f"Referensi {i} tidak ada terjemahan"
            assert ref.get("surah"), f"Referensi {i} tidak ada nama surah"
            assert ref.get("ayat"), f"Referensi {i} tidak ada nomor ayat"
        print(f"\n[kiamat] {len(data['referensi'])} referensi, semua lengkap")

    def test_top_k_mempengaruhi_jumlah_referensi(self):
        """top_k=1 harus kembalikan max 1, top_k=5 bisa lebih banyak."""
        time.sleep(2)

        data_1 = _ask("Apa makna ayat kursi?", top_k=1)
        time.sleep(3)
        data_5 = _ask("Apa makna ayat kursi?", top_k=5)

        n1 = len(data_1["referensi"])
        n5 = len(data_5["referensi"])
        print(f"\n[top_k] top_k=1 → {n1} ref, top_k=5 → {n5} ref")
        assert n1 <= 1, f"top_k=1 tapi dapat {n1} referensi"
        assert n5 >= n1, f"top_k=5 ({n5}) tidak lebih banyak dari top_k=1 ({n1})"


# ═══════════════════════════════════════════════════════
#  EDGE CASES
# ═══════════════════════════════════════════════════════


class TestEdgeCases:
    """Tes tepi: pertanyaan aneh, input minimal, dll."""

    def test_pertanyaan_sangat_pendek(self):
        """Pertanyaan 3 karakter (batas minimum) masih bisa dijawab."""
        data = _ask("doa")
        print(f"\n[pendek] status={data['status']}, skor={data['skor_tertinggi']:.4f}")
        print(f"[pendek] jawaban: {data['jawaban_llm'][:100]}...")

    def test_pertanyaan_panjang(self):
        """Pertanyaan panjang (~200 karakter) tidak menyebabkan error."""
        q = (
            "Saya ingin memahami secara mendalam tentang konsep keadilan "
            "dalam Al-Quran, bagaimana Allah SWT memerintahkan manusia untuk "
            "berlaku adil dalam segala aspek kehidupan, baik dalam hubungan "
            "keluarga, masyarakat, maupun bernegara."
        )
        data = _ask(q)
        assert data["status"] == "success"
        print(f"\n[panjang] jawaban: {data['jawaban_llm'][:150]}...")

    def test_pertanyaan_dengan_kata_arab(self):
        """Pertanyaan campur bahasa Indonesia dan istilah Arab."""
        data = _ask("Apa makna istighfar dan taubat menurut Al-Quran?")
        assert data["status"] == "success"
        print(f"\n[arab] jawaban: {data['jawaban_llm'][:150]}...")
