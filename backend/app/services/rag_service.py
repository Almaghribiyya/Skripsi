"""
RAGService — Orkestrator utama pipeline Retrieval-Augmented Generation.

Tanggung jawab:
  1. Menerima pertanyaan pengguna.
  2. Memanggil EmbeddingService untuk retrieval (similarity search).
  3. Menerapkan SCORE THRESHOLD (grounded generation gate).
  4. Merakit konteks dari chunk yang relevan.
  5. Memanggil LLMService untuk generation.
  6. Mengembalikan hasil terstruktur (jawaban + referensi).

Keputusan arsitektural:
- Score threshold mencegah LLM mendapat konteks yang tidak relevan.
  Jika skor tertinggi di bawah ambang, sistem langsung menolak secara
  halus (negative rejection) TANPA memanggil LLM — menghemat biaya API.
- Service ini tidak bergantung pada framework HTTP (FastAPI), sehingga
  bisa di-test secara independen (unit test).
"""

import logging
from dataclasses import dataclass

from app.config import Settings
from app.models.schemas import ReferensiItem, QueryResponse
from app.services.embedding_service import EmbeddingService
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)

NO_DATA_MESSAGE = "Sistem belum memiliki data ayat yang cukup untuk menjawab pertanyaan ini."

LOW_RELEVANCE_MESSAGE = (
    "Mohon maaf, saya tidak menemukan ayat Al-Qur'an yang cukup relevan "
    "dengan pertanyaan Anda. Silakan coba ajukan pertanyaan dengan kata kunci "
    "yang lebih spesifik terkait tema dalam Al-Qur'an."
)


class RAGService:
    """Orkestrator pipeline RAG: Retrieve → Gate → Generate."""

    def __init__(
        self,
        embedding_service: EmbeddingService,
        llm_service: LLMService,
        settings: Settings,
    ) -> None:
        self._embedding = embedding_service
        self._llm = llm_service
        self._threshold = settings.similarity_threshold

    def answer(self, pertanyaan: str, top_k: int = 3) -> QueryResponse:
        """
        Pipeline utama RAG.

        Args:
            pertanyaan: Pertanyaan pengguna dalam bahasa Indonesia.
            top_k: Jumlah dokumen referensi yang diambil (1-5).

        Returns:
            QueryResponse berisi jawaban LLM dan referensi ayat.
        """

        # ── Tahap A: Retrieval ────────────────────────────────────────
        chunks = self._embedding.retrieve(query=pertanyaan, top_k=top_k)

        if not chunks:
            logger.info("Retrieval menghasilkan 0 chunk untuk: '%s'", pertanyaan)
            return QueryResponse(
                status="success",
                pertanyaan=pertanyaan,
                jawaban_llm=NO_DATA_MESSAGE,
                referensi=[],
                skor_tertinggi=0.0,
            )

        skor_tertinggi = chunks[0].score  # chunks sudah diurutkan descending

        # ── Tahap B: Score Threshold Gate (Grounded Generation) ───────
        if skor_tertinggi < self._threshold:
            logger.info(
                "Skor tertinggi (%.4f) < threshold (%.4f). Negative rejection.",
                skor_tertinggi,
                self._threshold,
            )
            # Tetap kembalikan referensi agar user bisa nilai sendiri
            referensi = [
                ReferensiItem(
                    skor_kemiripan=round(c.score, 4),
                    surah=c.nama_surah,
                    ayat=c.ayat,
                    teks_arab=c.teks_arab,
                    terjemahan=c.terjemahan,
                )
                for c in chunks
            ]
            return QueryResponse(
                status="success",
                pertanyaan=pertanyaan,
                jawaban_llm=LOW_RELEVANCE_MESSAGE,
                referensi=referensi,
                skor_tertinggi=round(skor_tertinggi, 4),
            )

        # ── Tahap C: Rakit Konteks ────────────────────────────────────
        konteks_parts: list[str] = []
        referensi: list[ReferensiItem] = []

        for chunk in chunks:
            konteks_parts.append(
                f"Surah {chunk.nama_surah} Ayat {chunk.ayat}:\n"
                f"Terjemahan: {chunk.terjemahan}\n"
                f"Tafsir: {chunk.tafsir_wajiz}"
            )
            referensi.append(
                ReferensiItem(
                    skor_kemiripan=round(chunk.score, 4),
                    surah=chunk.nama_surah,
                    ayat=chunk.ayat,
                    teks_arab=chunk.teks_arab,
                    terjemahan=chunk.terjemahan,
                )
            )

        konteks_teks = "\n\n".join(konteks_parts)

        # ── Tahap D: Generation ───────────────────────────────────────
        jawaban = self._llm.generate(konteks=konteks_teks, pertanyaan=pertanyaan)

        logger.info(
            "RAG pipeline selesai: pertanyaan='%s', skor_tertinggi=%.4f, refs=%d",
            pertanyaan[:50],
            skor_tertinggi,
            len(referensi),
        )

        return QueryResponse(
            status="success",
            pertanyaan=pertanyaan,
            jawaban_llm=jawaban,
            referensi=referensi,
            skor_tertinggi=round(skor_tertinggi, 4),
        )
