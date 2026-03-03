# orkestrator utama pipeline rag (retrieval-augmented generation).
# v3: sepenuhnya async untuk tidak memblokir event loop FastAPI.
# mendukung dua mode: answer (langsung) dan stream_answer (SSE).
#
# konteks yang dikirim ke LLM termasuk teks arab, transliterasi,
# dan tafsir tahlili. deduplikasi chunk dari ayat yang sama
# juga ditangani di sini.

import logging

from app.config import Settings
from app.models.schemas import ReferensiItem, QueryResponse
from app.services.embedding_service import EmbeddingService, RetrievedChunk
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)

NO_DATA_MESSAGE = (
    "Sistem belum memiliki data ayat yang cukup "
    "untuk menjawab pertanyaan ini."
)

LOW_RELEVANCE_MESSAGE = (
    "Mohon maaf, saya tidak menemukan ayat Al-Qur'an yang cukup relevan "
    "dengan pertanyaan Anda. Silakan coba ajukan pertanyaan dengan kata kunci "
    "yang lebih spesifik terkait tema dalam Al-Qur'an."
)


def _deduplicate_chunks(chunks: list[RetrievedChunk]) -> list[RetrievedChunk]:
    """Hanya pertahankan chunk dengan skor tertinggi per ayat."""
    seen: dict[str, RetrievedChunk] = {}
    for chunk in chunks:
        key = f"{chunk.surah}-{chunk.ayat}"
        if key not in seen or chunk.score > seen[key].score:
            seen[key] = chunk
    return list(seen.values())


class RAGService:
    """Async orkestrator pipeline rag: retrieve, gate, generate/stream."""

    def __init__(
        self,
        embedding_service: EmbeddingService,
        llm_service: LLMService,
        settings: Settings,
    ) -> None:
        self._embedding = embedding_service
        self._llm = llm_service
        self._threshold = settings.similarity_threshold

    # ─── shared helpers ──────────────────────────────────────────

    async def _retrieve_chunks(self, pertanyaan: str, top_k: int):
        """Retrieve, deduplicate, sort. Returns (chunks, skor_tertinggi)."""
        raw = await self._embedding.retrieve(
            query=pertanyaan, top_k=min(top_k + 2, 10)
        )
        if not raw:
            return [], 0.0
        chunks = _deduplicate_chunks(raw)
        chunks.sort(key=lambda c: c.score, reverse=True)
        chunks = chunks[:top_k]
        return chunks, chunks[0].score

    @staticmethod
    def _build_referensi(chunks: list[RetrievedChunk]) -> list[ReferensiItem]:
        return [
            ReferensiItem(
                skor_kemiripan=round(c.score, 4),
                surah=c.nama_surah, ayat=c.ayat,
                teks_arab=c.teks_arab, terjemahan=c.terjemahan,
                transliterasi=c.transliterasi,
            )
            for c in chunks
        ]

    @staticmethod
    def _build_context(chunks: list[RetrievedChunk]) -> str:
        parts = []
        for c in chunks:
            parts.append(
                f"--- Surah {c.nama_surah} Ayat {c.ayat} ---\n"
                f"Teks Arab: {c.teks_arab}\n"
                f"Transliterasi: {c.transliterasi}\n"
                f"Terjemahan: {c.terjemahan}\n"
                f"Tafsir Ringkas: {c.tafsir_wajiz}\n"
                f"Tafsir Tahlili: {c.tafsir_tahlili}"
            )
        return "\n\n".join(parts)

    @staticmethod
    def _build_riwayat(riwayat_percakapan) -> str:
        if not riwayat_percakapan:
            return ""
        parts = []
        for item in riwayat_percakapan:
            peran = "Pengguna" if item.peran == "user" else "Asisten"
            parts.append(f"{peran}: {item.konten[:500]}")
        return "\n".join(parts)

    # ─── direct answer mode ─────────────────────────────────────

    async def answer(
        self,
        pertanyaan: str,
        top_k: int = 5,
        riwayat_percakapan: list | None = None,
    ) -> QueryResponse:
        """Jalankan pipeline rag dan kembalikan QueryResponse."""
        chunks, skor = await self._retrieve_chunks(pertanyaan, top_k)

        if not chunks:
            logger.info("0 chunk untuk: '%s'", pertanyaan)
            return QueryResponse(
                status="success", pertanyaan=pertanyaan,
                jawaban_llm=NO_DATA_MESSAGE, referensi=[],
                skor_tertinggi=0.0,
            )

        referensi = self._build_referensi(chunks)

        if skor < self._threshold:
            logger.info("Skor %.4f < threshold %.4f → rejection", skor, self._threshold)
            return QueryResponse(
                status="success", pertanyaan=pertanyaan,
                jawaban_llm=LOW_RELEVANCE_MESSAGE,
                referensi=referensi, skor_tertinggi=round(skor, 4),
            )

        konteks = self._build_context(chunks)
        riwayat = self._build_riwayat(riwayat_percakapan)

        jawaban = await self._llm.generate(
            konteks=konteks, pertanyaan=pertanyaan, riwayat=riwayat,
        )

        logger.info(
            "RAG done: q='%s' skor=%.4f refs=%d",
            pertanyaan[:50], skor, len(referensi),
        )
        return QueryResponse(
            status="success", pertanyaan=pertanyaan,
            jawaban_llm=jawaban, referensi=referensi,
            skor_tertinggi=round(skor, 4),
        )

    # ─── SSE streaming mode ─────────────────────────────────────

    async def stream_answer(
        self,
        pertanyaan: str,
        top_k: int = 5,
        riwayat_percakapan: list | None = None,
    ):
        """Async generator yielding dicts untuk Server-Sent Events."""
        chunks, skor = await self._retrieve_chunks(pertanyaan, top_k)

        if not chunks:
            yield {
                "type": "complete",
                "response": QueryResponse(
                    status="success", pertanyaan=pertanyaan,
                    jawaban_llm=NO_DATA_MESSAGE, referensi=[],
                    skor_tertinggi=0.0,
                ).model_dump(),
            }
            return

        referensi = self._build_referensi(chunks)

        if skor < self._threshold:
            yield {
                "type": "complete",
                "response": QueryResponse(
                    status="success", pertanyaan=pertanyaan,
                    jawaban_llm=LOW_RELEVANCE_MESSAGE,
                    referensi=referensi, skor_tertinggi=round(skor, 4),
                ).model_dump(),
            }
            return

        # kirim referensi dulu sebelum streaming LLM
        yield {
            "type": "referensi",
            "referensi": [r.model_dump() for r in referensi],
            "skor_tertinggi": round(skor, 4),
            "pertanyaan": pertanyaan,
        }

        # stream token LLM
        konteks = self._build_context(chunks)
        riwayat = self._build_riwayat(riwayat_percakapan)
        async for token in self._llm.stream(
            konteks=konteks, pertanyaan=pertanyaan, riwayat=riwayat,
        ):
            yield {"type": "token", "content": token}

        yield {"type": "done"}
