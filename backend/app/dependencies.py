"""
Dependency Injection untuk FastAPI.

Modul ini bertanggung jawab atas lifecycle management dari service-service
berat (embedding model, LLM connections, vector store client).

Prinsip: Inisialisasi sekali saat startup, inject via FastAPI Depends().
Manfaat: Service bisa di-mock dengan mudah saat testing.
"""

import logging
from functools import lru_cache

from app.config import Settings, get_settings
from app.services.embedding_service import EmbeddingService
from app.services.llm_service import LLMService
from app.services.rag_service import RAGService

logger = logging.getLogger(__name__)

# Singleton instances — dibuat sekali, dipakai ulang.
_embedding_service: EmbeddingService | None = None
_llm_service: LLMService | None = None
_rag_service: RAGService | None = None


def init_services(settings: Settings) -> None:
    """
    Inisialisasi semua heavy service saat application startup.
    Dipanggil dari FastAPI lifespan event.
    """
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
    """FastAPI dependency: inject RAGService."""
    if _rag_service is None:
        raise RuntimeError(
            "RAGService belum diinisialisasi. "
            "Pastikan init_services() dipanggil saat startup."
        )
    return _rag_service


def get_embedding_service() -> EmbeddingService:
    """FastAPI dependency: inject EmbeddingService."""
    if _embedding_service is None:
        raise RuntimeError("EmbeddingService belum diinisialisasi.")
    return _embedding_service
