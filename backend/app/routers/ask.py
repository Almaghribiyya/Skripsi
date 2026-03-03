# router untuk endpoint utama tanya jawab al-quran.
# mendukung dua mode: /api/ask (langsung) dan /api/ask/stream (SSE).

import json
import logging

from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import Settings, get_settings
from app.dependencies import get_rag_service
from app.middleware.firebase_auth import verify_firebase_token
from app.models.schemas import QueryRequest, QueryResponse, ErrorResponse
from app.services.rag_service import RAGService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["Q&A Al-Qur'an"])

# instance rate limiter, di-share dengan app.state.limiter di main.py
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
    description="Menerima pertanyaan dan menghasilkan jawaban berbasis konteks ayat.",
)
@limiter.limit("10/minute")
async def ask_quran(
    request: Request,
    payload: QueryRequest,
    user: dict = Depends(verify_firebase_token),
    rag_service: RAGService = Depends(get_rag_service),
    settings: Settings = Depends(get_settings),
):
    """Pipeline rag async: retrieval, score gate, generation."""
    uid = user.get("uid", "anonymous") if user else "auth-disabled"
    logger.info("Pertanyaan dari user=%s: '%s'", uid, payload.pertanyaan[:80])

    result = await rag_service.answer(
        pertanyaan=payload.pertanyaan,
        top_k=payload.top_k,
        riwayat_percakapan=payload.riwayat_percakapan or None,
    )

    return result


@router.post(
    "/ask/stream",
    summary="Tanya Jawab Al-Qur'an (Streaming)",
    description=(
        "Sama seperti /ask tapi mengembalikan SSE stream. "
        "Event types: 'referensi', 'token', 'done', 'complete'."
    ),
    responses={
        401: {"model": ErrorResponse},
        429: {"description": "Rate limit exceeded."},
    },
)
@limiter.limit("10/minute")
async def ask_quran_stream(
    request: Request,
    payload: QueryRequest,
    user: dict = Depends(verify_firebase_token),
    rag_service: RAGService = Depends(get_rag_service),
):
    """Pipeline rag dengan SSE streaming untuk jawaban LLM token-by-token."""
    uid = user.get("uid", "anonymous") if user else "auth-disabled"
    logger.info("Stream dari user=%s: '%s'", uid, payload.pertanyaan[:80])

    async def _event_generator():
        async for event in rag_service.stream_answer(
            pertanyaan=payload.pertanyaan,
            top_k=payload.top_k,
            riwayat_percakapan=payload.riwayat_percakapan or None,
        ):
            yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        _event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
