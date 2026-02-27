# modul ini mengatur dependency injection untuk fastapi.
# semua service berat seperti embedding model, koneksi llm, dan qdrant
# diinisialisasi sekali saat startup lalu di-inject lewat depends().
# cara ini juga memudahkan testing karena tinggal di-mock.

import logging
from functools import lru_cache

from app.config import Settings, get_settings
from app.services.embedding_service import EmbeddingService
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService

logger = logging.getLogger(__name__)

# instance singleton, dibuat sekali saat startup dan dipakai terus
_embedding_service: EmbeddingService | None = None
_llm_service: LLMService | None = None
_rag_service: RAGService | None = None


def init_services(settings: Settings) -> None:
    """Inisialisasi semua service berat saat aplikasi pertama kali jalan.
    Dipanggil dari lifespan event di main.py."""
    global _embedding_service, _llm_service, _rag_service

    logger.info("Initializing services...")

    _embedding_service = EmbeddingService(settings)
    _llm_service = LLMService(settings)
    _rag_service = RAGService(
        embedding_service=_embedding_service,
        llm_service=_llm_service,
        settings=settings,
    )

    logger.info("All services initialized successfully.")


def get_rag_service() -> RAGService:
    """Dependency untuk inject rag service ke endpoint yang membutuhkan."""
    if _rag_service is None:
        raise RuntimeError(
            "RAGService belum diinisialisasi. "
            "Pastikan init_services() dipanggil saat startup."
        )
    return _rag_service


def get_embedding_service() -> EmbeddingService:
    """Dependency untuk inject embedding service, dipakai di health check."""
    if _embedding_service is None:
        raise RuntimeError("EmbeddingService belum diinisialisasi.")
    return _embedding_service
