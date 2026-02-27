"""
EmbeddingService — Tanggung jawab tunggal: inisialisasi model embedding
dan operasi retrieval terhadap Qdrant vector store.

Prinsip arsitektural:
- Lazy initialization via singleton pattern agar model hanya dimuat sekali.
- Method `retrieve()` mengembalikan data terstruktur, bukan objek LangChain,
  sehingga layer di atasnya tidak terikat pada implementasi vector store.
"""

import logging
from dataclasses import dataclass

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

from app.config import Settings

logger = logging.getLogger(__name__)


@dataclass
class RetrievedChunk:
    """Representasi satu chunk hasil retrieval dari vector store."""

    score: float
    nama_surah: str
    ayat: int
    teks_arab: str
    terjemahan: str
    tafsir_wajiz: str
    tafsir_tahlili: str


class EmbeddingService:
    """Mengelola koneksi ke Qdrant dan operasi similarity search."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._embeddings = HuggingFaceEmbeddings(
            model_name=settings.embedding_model,
            model_kwargs={"device": settings.embedding_device},
            encode_kwargs={"normalize_embeddings": True},
        )
        self._qdrant_client = QdrantClient(url=settings.qdrant_url)
        self._vector_store = QdrantVectorStore(
            client=self._qdrant_client,
            collection_name=settings.qdrant_collection,
            embedding=self._embeddings,
        )
        logger.info(
            "EmbeddingService initialized: model=%s, qdrant=%s, collection=%s",
            settings.embedding_model,
            settings.qdrant_url,
            settings.qdrant_collection,
        )

    def retrieve(self, query: str, top_k: int = 3) -> list[RetrievedChunk]:
        """
        Melakukan similarity search terhadap query pengguna.

        Returns:
            List[RetrievedChunk] diurutkan dari skor tertinggi.
        """
        raw_results = self._vector_store.similarity_search_with_score(
            query=query, k=top_k
        )

        chunks: list[RetrievedChunk] = []
        for doc, score in raw_results:
            meta = doc.metadata
            chunks.append(
                RetrievedChunk(
                    score=float(score),
                    nama_surah=meta.get("nama_surah", "Tidak Diketahui"),
                    ayat=int(meta.get("ayat", 0)),
                    teks_arab=meta.get("teks_arab", ""),
                    terjemahan=meta.get("terjemahan", ""),
                    tafsir_wajiz=meta.get("tafsir_wajiz", ""),
                    tafsir_tahlili=meta.get("tafsir_tahlili", ""),
                )
            )

        # Urutkan descending berdasarkan skor (cosine similarity)
        chunks.sort(key=lambda c: c.score, reverse=True)
        return chunks

    def health_check(self) -> bool:
        """Cek apakah Qdrant bisa dihubungi."""
        try:
            self._qdrant_client.get_collections()
            return True
        except Exception:
            return False
