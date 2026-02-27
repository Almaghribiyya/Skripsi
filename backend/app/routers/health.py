# router untuk health check dan informasi status sistem.
# tidak butuh autentikasi, dipakai untuk monitoring.

from fastapi import APIRouter, Depends

from app.config import Settings, get_settings
from app.dependencies import get_embedding_service
from app.models.schemas import HealthResponse
from app.services.embedding_service import EmbeddingService

router = APIRouter(tags=["Health Check"])


@router.get("/", response_model=HealthResponse)
async def root(settings: Settings = Depends(get_settings)):
    """Endpoint utama untuk cek apakah backend sudah jalan."""
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
    """Health check detail yang juga mengecek koneksi ke qdrant."""
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
