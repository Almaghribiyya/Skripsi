# test untuk memory buffer — riwayat percakapan di RAG pipeline.
# verifikasi bahwa riwayat_percakapan diformat dengan benar
# dan dikirim ke LLM sebagai konteks memori.

import pytest
from unittest.mock import MagicMock, AsyncMock

from app.config import Settings
from app.models.schemas import RiwayatItem
from app.services.embedding_service import EmbeddingService, RetrievedChunk
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService


def _make_chunk(score=0.85):
    return RetrievedChunk(
        score=score,
        surah=2,
        nama_surah="Al-Baqarah",
        ayat=255,
        teks_arab="اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ",
        transliterasi="Allāhu lā ilāha illā huwa",
        terjemahan="Allah, tidak ada tuhan selain Dia",
        tafsir_wajiz="Ayat Kursi.",
        tafsir_tahlili="Tafsir lengkap.",
        kategori_surah="Madaniyyah",
        chunk_index=0,
        total_chunks=1,
    )


def _make_service(llm_answer="Jawaban"):
    mock_embedding = MagicMock(spec=EmbeddingService)
    mock_embedding.retrieve = AsyncMock(return_value=[_make_chunk()])

    mock_llm = MagicMock(spec=LLMService)
    mock_llm.generate = AsyncMock(return_value=llm_answer)

    settings = MagicMock(spec=Settings)
    settings.similarity_threshold = 0.45

    return RAGService(
        embedding_service=mock_embedding,
        llm_service=mock_llm,
        settings=settings,
    ), mock_llm


@pytest.mark.asyncio
async def test_riwayat_passed_to_llm():
    """Riwayat percakapan harus sampai ke LLM.generate() sebagai teks."""
    rag, mock_llm = _make_service()
    riwayat = [
        RiwayatItem(peran="user", konten="Apa itu sabar?"),
        RiwayatItem(peran="ai", konten="Sabar adalah menahan diri..."),
    ]

    await rag.answer("Jelaskan lebih lanjut", riwayat_percakapan=riwayat)

    call_kwargs = mock_llm.generate.call_args
    riwayat_text = call_kwargs.kwargs.get("riwayat") or call_kwargs[1].get("riwayat", "")
    assert "Pengguna: Apa itu sabar?" in riwayat_text
    assert "Asisten: Sabar adalah menahan diri..." in riwayat_text


@pytest.mark.asyncio
async def test_no_riwayat_sends_empty_string():
    """Tanpa riwayat, LLM harus dapat string kosong."""
    rag, mock_llm = _make_service()
    await rag.answer("Apa itu iman?")

    call_kwargs = mock_llm.generate.call_args
    riwayat_text = call_kwargs.kwargs.get("riwayat") or call_kwargs[1].get("riwayat", "")
    assert riwayat_text == ""


@pytest.mark.asyncio
async def test_riwayat_truncated_to_500_chars():
    """Konten riwayat yang terlalu panjang harus dipotong 500 karakter."""
    rag, mock_llm = _make_service()
    long_text = "A" * 1000
    riwayat = [RiwayatItem(peran="user", konten=long_text)]

    await rag.answer("Lanjutkan", riwayat_percakapan=riwayat)

    call_kwargs = mock_llm.generate.call_args
    riwayat_text = call_kwargs.kwargs.get("riwayat") or call_kwargs[1].get("riwayat", "")
    # konten di-truncate jadi 500 karakter oleh rag_service
    assert len(riwayat_text) < 1000


@pytest.mark.asyncio
async def test_empty_riwayat_list_treated_as_none():
    """List riwayat kosong harus sama hasilnya dengan None."""
    rag, mock_llm = _make_service()
    await rag.answer("Apa itu taqwa?", riwayat_percakapan=[])

    call_kwargs = mock_llm.generate.call_args
    riwayat_text = call_kwargs.kwargs.get("riwayat") or call_kwargs[1].get("riwayat", "")
    assert riwayat_text == ""


@pytest.mark.asyncio
async def test_riwayat_with_multiple_turns():
    """Riwayat multi-turn harus diformat berurutan."""
    rag, mock_llm = _make_service()
    riwayat = [
        RiwayatItem(peran="user", konten="Pertanyaan pertama"),
        RiwayatItem(peran="ai", konten="Jawaban pertama"),
        RiwayatItem(peran="user", konten="Pertanyaan kedua"),
        RiwayatItem(peran="ai", konten="Jawaban kedua"),
    ]

    await rag.answer("Pertanyaan ketiga", riwayat_percakapan=riwayat)

    call_kwargs = mock_llm.generate.call_args
    riwayat_text = call_kwargs.kwargs.get("riwayat") or call_kwargs[1].get("riwayat", "")
    # verifikasi urutan benar
    idx_p1 = riwayat_text.index("Pertanyaan pertama")
    idx_j1 = riwayat_text.index("Jawaban pertama")
    idx_p2 = riwayat_text.index("Pertanyaan kedua")
    idx_j2 = riwayat_text.index("Jawaban kedua")
    assert idx_p1 < idx_j1 < idx_p2 < idx_j2
