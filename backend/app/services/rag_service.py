# orkestrator utama pipeline rag (retrieval-augmented generation).
# alur kerjanya: terima pertanyaan, cari ayat yang relevan di qdrant,
# cek apakah skor cukup tinggi, kalau iya rakit konteks dan panggil llm.
# kalau skor rendah, langsung tolak halus tanpa panggil llm.
#
# v2: konteks yang dikirim ke LLM sekarang termasuk teks arab, transliterasi,
# dan tafsir tahlili supaya LLM bisa menyajikan jawaban yang lebih kaya.
# deduplikasi chunk dari ayat yang sama juga ditangani di sini.

import logging

from app.config import Settings
from app.models.schemas import ReferensiItem, QueryResponse
from app.services.embedding_service import EmbeddingService, RetrievedChunk
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)

# pesan kalau tidak ada data ayat sama sekali
NO_DATA_MESSAGE = "Sistem belum memiliki data ayat yang cukup untuk menjawab pertanyaan ini."

# pesan kalau skor similarity di bawah threshold
LOW_RELEVANCE_MESSAGE = (
    "Mohon maaf, saya tidak menemukan ayat Al-Qur'an yang cukup relevan "
    "dengan pertanyaan Anda. Silakan coba ajukan pertanyaan dengan kata kunci "
    "yang lebih spesifik terkait tema dalam Al-Qur'an."
)


def _deduplicate_chunks(chunks: list[RetrievedChunk]) -> list[RetrievedChunk]:
    """Deduplikasi chunk dari ayat yang sama (akibat tafsir splitting).
    Hanya pertahankan chunk dengan skor tertinggi per ayat."""
    seen: dict[str, RetrievedChunk] = {}
    for chunk in chunks:
        key = f"{chunk.surah}-{chunk.ayat}"
        if key not in seen or chunk.score > seen[key].score:
            seen[key] = chunk
    return list(seen.values())


class RAGService:
    """Orkestrator pipeline rag: retrieve, gate, generate."""

    def __init__(
        self,
        embedding_service: EmbeddingService,
        llm_service: LLMService,
        settings: Settings,
    ) -> None:
        self._embedding = embedding_service
        self._llm = llm_service
        self._threshold = settings.similarity_threshold

    def answer(
        self,
        pertanyaan: str,
        top_k: int = 5,
        riwayat_percakapan: list | None = None,
    ) -> QueryResponse:
        """Jalankan seluruh pipeline rag untuk satu pertanyaan.
        Jika riwayat_percakapan diberikan, LLM akan mempertimbangkan
        konteks percakapan sebelumnya."""

        # cari ayat yang relevan lewat similarity search
        # ambil lebih banyak (top_k+2) untuk mengompensasi deduplikasi chunk
        raw_chunks = self._embedding.retrieve(
            query=pertanyaan, top_k=min(top_k + 2, 10)
        )

        if not raw_chunks:
            logger.info("Retrieval menghasilkan 0 chunk untuk: '%s'", pertanyaan)
            return QueryResponse(
                status="success",
                pertanyaan=pertanyaan,
                jawaban_llm=NO_DATA_MESSAGE,
                referensi=[],
                skor_tertinggi=0.0,
            )

        # deduplikasi chunk dari ayat yang sama, ambil yang skor tertinggi
        chunks = _deduplicate_chunks(raw_chunks)
        chunks.sort(key=lambda c: c.score, reverse=True)
        chunks = chunks[:top_k]  # potong sesuai jumlah yang diminta

        # chunks sudah diurutkan descending, ambil skor tertinggi
        skor_tertinggi = chunks[0].score

        # cek apakah skor cukup tinggi, kalau tidak tolak halus
        if skor_tertinggi < self._threshold:
            logger.info(
                "Skor tertinggi (%.4f) < threshold (%.4f). Negative rejection.",
                skor_tertinggi,
                self._threshold,
            )
            # tetap kembalikan referensi supaya user bisa lihat sendiri
            referensi = [
                ReferensiItem(
                    skor_kemiripan=round(c.score, 4),
                    surah=c.nama_surah,
                    ayat=c.ayat,
                    teks_arab=c.teks_arab,
                    terjemahan=c.terjemahan,
                    transliterasi=c.transliterasi,
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

        # rakit konteks KAYA dari chunk-chunk yang relevan untuk dikirim ke llm
        # sertakan semua metadata supaya LLM bisa menenun jawaban yang lengkap
        konteks_parts: list[str] = []
        referensi: list[ReferensiItem] = []

        for chunk in chunks:
            # konteks lengkap untuk LLM — termasuk teks arab dan transliterasi
            konteks_parts.append(
                f"--- Surah {chunk.nama_surah} Ayat {chunk.ayat} ---\n"
                f"Teks Arab: {chunk.teks_arab}\n"
                f"Transliterasi: {chunk.transliterasi}\n"
                f"Terjemahan: {chunk.terjemahan}\n"
                f"Tafsir Ringkas: {chunk.tafsir_wajiz}\n"
                f"Tafsir Tahlili: {chunk.tafsir_tahlili}"
            )
            referensi.append(
                ReferensiItem(
                    skor_kemiripan=round(chunk.score, 4),
                    surah=chunk.nama_surah,
                    ayat=chunk.ayat,
                    teks_arab=chunk.teks_arab,
                    terjemahan=chunk.terjemahan,
                    transliterasi=chunk.transliterasi,
                )
            )

        konteks_teks = "\n\n".join(konteks_parts)

        # rakit riwayat percakapan jadi teks untuk dikirim ke llm
        riwayat_teks = ""
        if riwayat_percakapan:
            riwayat_parts = []
            for item in riwayat_percakapan:
                peran = "Pengguna" if item.peran == "user" else "Asisten"
                # potong konten yang terlalu panjang untuk menghemat token
                konten = item.konten[:500]
                riwayat_parts.append(f"{peran}: {konten}")
            riwayat_teks = "\n".join(riwayat_parts)

        # panggil llm untuk generate jawaban berdasarkan konteks ayat
        jawaban = self._llm.generate(
            konteks=konteks_teks,
            pertanyaan=pertanyaan,
            riwayat=riwayat_teks,
        )

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
