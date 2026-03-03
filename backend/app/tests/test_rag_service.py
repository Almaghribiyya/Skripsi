# test untuk RAGService, logika inti pipeline rag.
# semua test ini murni unit test async, tidak butuh Qdrant, LLM,
# atau koneksi jaringan apapun.

import pytest
from unittest.mock import MagicMock, AsyncMock

from app.config import Settings
from app.models.schemas import QueryResponse
from app.services.embedding_service import EmbeddingService, RetrievedChunk
from app.services.llm_service import LLMService, FALLBACK_MESSAGE
from app.services.rag_service import RAGService, NO_DATA_MESSAGE, LOW_RELEVANCE_MESSAGE


def _make_chunk(
    score: float, surah: str = "Al-Fatihah", ayat: int = 1, surah_num: int = 1,
) -> RetrievedChunk:
    """Bikin RetrievedChunk dummy untuk testing."""
    return RetrievedChunk(
        score=score,
        surah=surah_num,
        nama_surah=surah,
        ayat=ayat,
        teks_arab="بِسْمِ اللَّهِ",
        transliterasi="Bismillāh",
        terjemahan="Dengan nama Allah",
        tafsir_wajiz="Tafsir ringkas.",
        tafsir_tahlili="Tafsir lengkap.",
        kategori_surah="Makkiyyah",
        chunk_index=0,
        total_chunks=1,
    )


def _make_rag_service(
    chunks: list[RetrievedChunk],
    llm_answer: str = "Jawaban dari LLM.",
    threshold: float = 0.45,
) -> RAGService:
    """Bikin RAGService dengan mock async dependencies."""
    mock_embedding = MagicMock(spec=EmbeddingService)
    mock_embedding.retrieve = AsyncMock(return_value=chunks)

    mock_llm = MagicMock(spec=LLMService)
    mock_llm.generate = AsyncMock(return_value=llm_answer)

    settings = MagicMock(spec=Settings)
    settings.similarity_threshold = threshold

    return RAGService(
        embedding_service=mock_embedding,
        llm_service=mock_llm,
        settings=settings,
    )


@pytest.mark.asyncio
async def test_no_chunks_returns_no_data_message():
    """Retrieval 0 chunk harus kembalikan pesan no-data."""
    rag = _make_rag_service(chunks=[])
    result = await rag.answer("Apa itu iman?")

    assert result.status == "success"
    assert result.jawaban_llm == NO_DATA_MESSAGE
    assert result.referensi == []
    assert result.skor_tertinggi == 0.0


@pytest.mark.asyncio
async def test_low_score_triggers_negative_rejection():
    """Skor tertinggi di bawah threshold harus trigger negative rejection."""
    low_score_chunks = [_make_chunk(score=0.30)]
    rag = _make_rag_service(chunks=low_score_chunks, threshold=0.45)
    result = await rag.answer("Pertanyaan tidak relevan?")

    assert result.jawaban_llm == LOW_RELEVANCE_MESSAGE
    assert result.skor_tertinggi == 0.30
    assert len(result.referensi) == 1  # referensi tetap dikembalikan


@pytest.mark.asyncio
async def test_high_score_calls_llm():
    """Skor di atas threshold harus panggil LLM."""
    chunks = [_make_chunk(score=0.85, surah="Al-Baqarah", ayat=255)]
    rag = _make_rag_service(chunks=chunks, llm_answer="Ayat Kursi menjelaskan...")
    result = await rag.answer("Apa itu Ayat Kursi?")

    assert result.jawaban_llm == "Ayat Kursi menjelaskan..."
    assert result.skor_tertinggi == 0.85
    assert len(result.referensi) == 1
    assert result.referensi[0].surah == "Al-Baqarah"
    assert result.referensi[0].ayat == 255


@pytest.mark.asyncio
async def test_multiple_chunks_sorted_by_score():
    """Referensi harus urut dari skor tertinggi."""
    chunks = [
        _make_chunk(score=0.90, surah="Al-Ikhlas", ayat=1, surah_num=112),
        _make_chunk(score=0.75, surah="Al-Falaq", ayat=1, surah_num=113),
        _make_chunk(score=0.60, surah="An-Nas", ayat=1, surah_num=114),
    ]
    rag = _make_rag_service(chunks=chunks)
    result = await rag.answer("Apa itu tauhid?")

    assert len(result.referensi) == 3
    scores = [r.skor_kemiripan for r in result.referensi]
    assert scores == sorted(scores, reverse=True)


@pytest.mark.asyncio
async def test_exact_threshold_passes():
    """Skor yang tepat sama dengan threshold harus lolos gate."""
    chunks = [_make_chunk(score=0.45)]
    rag = _make_rag_service(chunks=chunks, threshold=0.45)
    result = await rag.answer("Pertanyaan pas threshold?")

    assert result.jawaban_llm != LOW_RELEVANCE_MESSAGE


@pytest.mark.asyncio
async def test_response_schema_completeness():
    """Response harus punya semua field yang diperlukan."""
    chunks = [_make_chunk(score=0.80)]
    rag = _make_rag_service(chunks=chunks)
    result = await rag.answer("Test schema?")

    assert hasattr(result, "status")
    assert hasattr(result, "pertanyaan")
    assert hasattr(result, "jawaban_llm")
    assert hasattr(result, "referensi")
    assert hasattr(result, "skor_tertinggi")
