# service untuk mengelola model embedding dan operasi retrieval
# ke qdrant vector store. retrieve() async untuk tidak memblokir
# event loop FastAPI saat melakukan similarity search.

import logging
from dataclasses import dataclass

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient, AsyncQdrantClient, models

from app.config import Settings

logger = logging.getLogger(__name__)


@dataclass
class RetrievedChunk:
    """Satu chunk hasil similarity search dari Qdrant."""

    score: float
    surah: int
    nama_surah: str
    ayat: int
    teks_arab: str
    transliterasi: str
    terjemahan: str
    tafsir_wajiz: str
    tafsir_tahlili: str
    kategori_surah: str
    chunk_index: int
    total_chunks: int


class EmbeddingService:
    """Koneksi ke Qdrant dan operasi async similarity search."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

        self._embeddings = HuggingFaceEmbeddings(
            model_name=settings.embedding_model,
            model_kwargs={"device": settings.embedding_device},
            encode_kwargs={"normalize_embeddings": True},
        )

        # klien sync untuk health check
        self._qdrant_client = QdrantClient(url=settings.qdrant_url)
        # klien async untuk retrieval tanpa blokir event loop
        self._async_client = AsyncQdrantClient(url=settings.qdrant_url)

        self._vector_store = QdrantVectorStore(
            client=self._qdrant_client,
            async_client=self._async_client,
            collection_name=settings.qdrant_collection,
            embedding=self._embeddings,
        )
        logger.info(
            "EmbeddingService initialized (async): model=%s, qdrant=%s",
            settings.embedding_model,
            settings.qdrant_url,
        )

    async def retrieve(self, query: str, top_k: int = 5) -> list[RetrievedChunk]:
        """Cari ayat yang paling mirip secara async.

        Menggunakan HNSW ef=128 untuk memaksimalkan recall
        tanpa mengorbankan kecepatan secara signifikan.
        """
        # prefix "query: " wajib untuk model e5 agar similarity search optimal
        prefixed_query = f"query: {query}"

        raw_results = await self._vector_store.asimilarity_search_with_score(
            query=prefixed_query,
            k=top_k,
            search_params=models.SearchParams(hnsw_ef=128, exact=False),
        )

        chunks: list[RetrievedChunk] = []
        for doc, score in raw_results:
            meta = doc.metadata
            chunks.append(
                RetrievedChunk(
                    score=float(score),
                    surah=int(meta.get("surah", 0)),
                    nama_surah=meta.get("nama_surah", "Tidak Diketahui"),
                    ayat=int(meta.get("ayat", 0)),
                    teks_arab=meta.get("teks_arab", ""),
                    transliterasi=meta.get("transliterasi", ""),
                    terjemahan=meta.get("terjemahan", ""),
                    tafsir_wajiz=meta.get("tafsir_wajiz", ""),
                    tafsir_tahlili=meta.get("tafsir_tahlili", ""),
                    kategori_surah=meta.get("kategori_surah", ""),
                    chunk_index=int(meta.get("chunk_index", 0)),
                    total_chunks=int(meta.get("total_chunks", 1)),
                )
            )

        chunks.sort(key=lambda c: c.score, reverse=True)
        return chunks

    def health_check(self) -> bool:
        """Cek apakah Qdrant bisa dihubungi (sync untuk probe sederhana)."""
        try:
            self._qdrant_client.get_collections()
            return True
        except Exception:
            return False
