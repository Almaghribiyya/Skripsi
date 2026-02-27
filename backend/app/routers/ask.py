"""
Router: Endpoint utama Q&A Al-Qur'an.

POST /api/ask — Menerima pertanyaan, mengembalikan jawaban RAG + referensi ayat.
"""

import logging

from fastapi import APIRouter, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import Settings, get_settings
from app.dependencies import get_rag_service
from app.middleware.firebase_auth import verify_firebase_token
from app.models.schemas import QueryRequest, QueryResponse, ErrorResponse
from app.services.rag_service import RAGService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["Q&A Al-Qur'an"])

# Rate limiter instance — akan di-share dengan app.state.limiter di main.py
limiter = Limiter(key_func=get_remote_address)


@router.post(
    "/ask",
    response_model=QueryResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Token tidak valid."},
        429: {"description": "Rate limit exceeded."},
        500: {"model": ErrorResponse, "description": "Internal server error."},
    },
    summary="Tanya Jawab Al-Qur'an",
    description=(
        "Menerima pertanyaan dalam bahasa Indonesia tentang Al-Qur'an. "
        "Melakukan similarity search terhadap 6.236 ayat, "
        "lalu menghasilkan jawaban menggunakan LLM berbasis konteks ayat."
    ),
)
@limiter.limit("10/minute")
async def ask_quran(
    request: Request,
    payload: QueryRequest,
    user: dict = Depends(verify_firebase_token),
    rag_service: RAGService = Depends(get_rag_service),
    settings: Settings = Depends(get_settings),
):
    """
    Pipeline RAG:
      1. Retrieval — Cosine similarity search di Qdrant.
      2. Score Gate — Tolak jika skor di bawah threshold (grounded generation).
      3. Generation — LLM menjawab berdasarkan konteks ayat.
      4. Fallback — Jika LLM gagal, kembalikan referensi ayat saja.
    """
    uid = user.get("uid", "anonymous") if user else "auth-disabled"
    logger.info("Pertanyaan dari user=%s: '%s'", uid, payload.pertanyaan[:80])

    result = rag_service.answer(
        pertanyaan=payload.pertanyaan,
        top_k=payload.top_k,
    )

    return result
