# integration test — percakapan nyata terhadap backend yang berjalan di docker.
# BUKAN unit test: test ini kirim request HTTP asli ke http://localhost:8000
# dan memverifikasi jawaban dari pipeline RAG (Qdrant + Gemini).
#
# prasyarat:
#   - docker compose up --build -d  (backend + qdrant harus running)
#   - qdrant sudah terisi data 6.236 ayat
#
# jalankan:
#   python -m pytest app/tests/test_conversation_integration.py -v -s
#
# catatan: test ini memanggil Gemini API secara nyata, jadi:
#   - butuh koneksi internet
#   - butuh GEMINI_API_KEY yang valid di .env
#   - agak lambat (~5-15 detik per pertanyaan)

import time
import requests
import pytest

BASE_URL = "http://localhost:8000"
ASK_URL = f"{BASE_URL}/api/ask"
HEALTH_URL = f"{BASE_URL}/"

# timeout per request (detik) — gemini bisa lambat
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
#  1. PERCAKAPAN TUNGGAL (single-turn) — tanpa riwayat
# ═══════════════════════════════════════════════════════


class TestSingleTurnConversation:
    """Satu pertanyaan, satu jawaban. Tidak ada konteks riwayat."""

    def test_pertanyaan_tentang_sabar(self):
        """Tanya tentang konsep sabar dalam Al-Quran."""
        data = _ask("Apa yang Al-Quran katakan tentang sabar?")

        assert data["status"] == "success"
        assert len(data["jawaban_llm"]) > 50, "Jawaban terlalu pendek"
        assert data["skor_tertinggi"] > 0.0
        # harus punya referensi ayat
        assert len(data["referensi"]) > 0, "Tidak ada referensi ayat"
        # cek struktur referensi
        ref = data["referensi"][0]
        assert "surah" in ref
        assert "ayat" in ref
        assert "teks_arab" in ref
        assert "terjemahan" in ref
        print(f"\n[sabar] skor={data['skor_tertinggi']:.4f}")
        print(f"[sabar] referensi: {len(data['referensi'])} ayat")
        print(f"[sabar] jawaban: {data['jawaban_llm'][:200]}...")

    def test_pertanyaan_tentang_sholat(self):
        """Tanya tentang sholat."""
        data = _ask("Bagaimana Al-Quran menjelaskan pentingnya sholat?")

        assert data["status"] == "success"
        assert len(data["jawaban_llm"]) > 50
        assert len(data["referensi"]) > 0
        print(f"\n[sholat] skor={data['skor_tertinggi']:.4f}")
        print(f"[sholat] jawaban: {data['jawaban_llm'][:200]}...")

    def test_pertanyaan_tentang_surah_alfatihah(self):
        """Tanya tentang surah Al-Fatihah — harus relevan."""
        data = _ask("Apa isi dan makna surah Al-Fatihah?")

        assert data["status"] == "success"
        assert len(data["jawaban_llm"]) > 50
        # idealnya referensi mengandung Al-Fatihah
        surah_names = [r.get("surah", "") for r in data["referensi"]]
        print(f"\n[al-fatihah] surah referensi: {surah_names}")
        print(f"[al-fatihah] jawaban: {data['jawaban_llm'][:200]}...")

    def test_pertanyaan_di_luar_konteks_alquran(self):
        """Pertanyaan non-Quran seharusnya ditolak atau dijawab dengan disclaimer."""
        data = _ask("Siapa presiden Indonesia pertama?")

        # sistem boleh jawab tapi skor harus rendah
        # atau jawaban berisi disclaimer
        print(f"\n[non-quran] skor={data['skor_tertinggi']:.4f}")
        print(f"[non-quran] status={data['status']}")
        print(f"[non-quran] jawaban: {data['jawaban_llm'][:200]}...")
        # tidak crash = sukses, konten diperiksa manual


# ═══════════════════════════════════════════════════════
#  2. PERCAKAPAN MULTI-GILIRAN (multi-turn) — dengan riwayat
# ═══════════════════════════════════════════════════════


class TestMultiTurnConversation:
    """Simulasikan percakapan nyata: tanya → jawab → tanya lagi.
    Riwayat dikirim ke backend supaya jawaban lebih kontekstual."""

    def test_percakapan_dua_giliran_tentang_taqwa(self):
        """Giliran 1: tanya definisi. Giliran 2: minta penjelasan lebih lanjut."""
        # --- Giliran 1 ---
        print("\n=== Percakapan Multi-Turn: Taqwa ===")
        turn1 = _ask("Apa itu taqwa menurut Al-Quran?")
        assert turn1["status"] == "success"
        assert len(turn1["jawaban_llm"]) > 30
        print(f"[turn1] jawaban: {turn1['jawaban_llm'][:150]}...")

        time.sleep(2)  # jeda supaya tidak kena rate limiter

        # --- Giliran 2 (dengan riwayat) ---
        riwayat = [
            {"peran": "user", "konten": "Apa itu taqwa menurut Al-Quran?"},
            {"peran": "ai", "konten": turn1["jawaban_llm"][:500]},
        ]
        turn2 = _ask(
            "Sebutkan ayat-ayat yang berkaitan dengan penjelasanmu tadi",
            riwayat=riwayat,
        )
        assert turn2["status"] == "success"
        assert len(turn2["jawaban_llm"]) > 30
        print(f"[turn2] jawaban: {turn2['jawaban_llm'][:200]}...")
        print(f"[turn2] referensi: {len(turn2['referensi'])} ayat")

    def test_percakapan_tiga_giliran_tentang_sedekah(self):
        """Tiga giliran berturut-turut tentang topik sedekah."""
        print("\n=== Percakapan Multi-Turn: Sedekah (3 giliran) ===")

        # --- Giliran 1 ---
        t1 = _ask("Apa hukum sedekah dalam Al-Quran?")
        assert t1["status"] == "success"
        print(f"[g1] jawaban: {t1['jawaban_llm'][:120]}...")

        time.sleep(2)

        # --- Giliran 2 ---
        riwayat_g2 = [
            {"peran": "user", "konten": "Apa hukum sedekah dalam Al-Quran?"},
            {"peran": "ai", "konten": t1["jawaban_llm"][:500]},
        ]
        t2 = _ask("Siapa saja yang berhak menerima sedekah?", riwayat=riwayat_g2)
        assert t2["status"] == "success"
        print(f"[g2] jawaban: {t2['jawaban_llm'][:120]}...")

        time.sleep(2)

        # --- Giliran 3 ---
        riwayat_g3 = riwayat_g2 + [
            {"peran": "user", "konten": "Siapa saja yang berhak menerima sedekah?"},
            {"peran": "ai", "konten": t2["jawaban_llm"][:500]},
        ]
        t3 = _ask(
            "Apa balasan bagi orang yang bersedekah?",
            riwayat=riwayat_g3,
        )
        assert t3["status"] == "success"
        assert len(t3["referensi"]) > 0
        print(f"[g3] jawaban: {t3['jawaban_llm'][:120]}...")
        print(f"[g3] referensi: {len(t3['referensi'])} ayat")


# ═══════════════════════════════════════════════════════
#  3. VALIDASI KUALITAS REFERENSI
# ═══════════════════════════════════════════════════════


class TestReferenceQuality:
    """Verifikasi bahwa referensi ayat memiliki struktur lengkap
    dan data yang masuk akal."""

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
        """top_k=1 seharusnya kembalikan maksimal 1 referensi,
        top_k=5 bisa sampai 5 referensi."""
        time.sleep(2)  # rate limiter jeda

        data_1 = _ask("Apa makna ayat kursi?", top_k=1)
        time.sleep(3)
        data_5 = _ask("Apa makna ayat kursi?", top_k=5)

        n1 = len(data_1["referensi"])
        n5 = len(data_5["referensi"])
        print(f"\n[top_k] top_k=1 → {n1} ref, top_k=5 → {n5} ref")
        # top_k=1 harus ≤ 1, top_k=5 bisa lebih banyak
        assert n1 <= 1, f"top_k=1 tapi dapat {n1} referensi"
        assert n5 >= n1, f"top_k=5 ({n5}) tidak lebih banyak dari top_k=1 ({n1})"


# ═══════════════════════════════════════════════════════
#  4. EDGE CASES
# ═══════════════════════════════════════════════════════


class TestEdgeCases:
    """Tes tepi: pertanyaan aneh, input minimal, dll."""

    def test_pertanyaan_sangat_pendek(self):
        """Pertanyaan 3 karakter (batas minimum) masih bisa dijawab."""
        data = _ask("doa")
        # boleh sukses atau dijawab dengan info terbatas
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
