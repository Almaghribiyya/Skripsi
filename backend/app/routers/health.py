"""
Router: Health Check & informasi sistem.
"""

from fastapi import APIRouter, Depends

from app.config import Settings, get_settings
from app.dependencies import get_embedding_service
from app.models.schemas import HealthResponse
from app.services.embedding_service import EmbeddingService

router = APIRouter(tags=["Health Check"])


@router.get("/", response_model=HealthResponse)
async def root(settings: Settings = Depends(get_settings)):
    """
    Endpoint utama untuk memeriksa status sistem.

    Tidak membutuhkan autentikasi.
    """
    return HealthResponse(
        status="ok",
        message="Qur'an RAG Backend is running. Kunjungi /docs untuk dokumentasi REST API.",
        version=settings.app_version,
    )


@router.get("/health", response_model=HealthResponse)
async def health_check(
    settings: Settings = Depends(get_settings),
    embedding_service: EmbeddingService = Depends(get_embedding_service),
):
    """
    Health check detail: memeriksa koneksi ke Qdrant.
    """
    qdrant_ok = embedding_service.health_check()
    if qdrant_ok:
        return HealthResponse(
            status="ok",
            message="Semua layanan berjalan normal.",
            version=settings.app_version,
        )
    return HealthResponse(
        status="degraded",
        message="Qdrant vector database tidak dapat dihubungi.",
        version=settings.app_version,
    )
