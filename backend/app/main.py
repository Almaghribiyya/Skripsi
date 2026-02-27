"""
Pustaka Digital Al-Qur'an — REST API (RAG Architecture)

Main application module: App Factory Pattern.
Semua business logic dipindahkan ke layer service & router.
File ini hanya bertanggung jawab atas:
  1. Membuat instance FastAPI.
  2. Mengonfigurasi middleware (CORS, Rate Limiter).
  3. Mendaftarkan router.
  4. Menginisialisasi service saat startup (lifespan).
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.config import get_settings
from app.dependencies import init_services
from app.routers import health, ask

# ── Logger ────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


# ── Lifespan (Startup / Shutdown) ────────────────────────────────────
@asynccontextmanager
async def lifespan(application: FastAPI):
    """
    Inisialisasi heavy resources (embedding model, LLM, Qdrant)
    saat startup. Lebih efisien daripada inisialisasi di modul level
    karena terkontrol dan bisa di-log.
    """
    settings = get_settings()
    logger.info("=" * 60)
    logger.info("STARTING %s v%s", settings.app_title, settings.app_version)
    logger.info("=" * 60)

    init_services(settings)

    logger.info("Auth enabled: %s", settings.auth_enabled)
    logger.info("Similarity threshold: %.2f", settings.similarity_threshold)
    logger.info("Rate limit: %s", settings.rate_limit)
    logger.info("Application ready to serve requests.")
    logger.info("=" * 60)

    yield  # Aplikasi berjalan

    logger.info("Shutting down application.")


# ── App Factory ──────────────────────────────────────────────────────
settings = get_settings()

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title=settings.app_title,
    description=settings.app_description,
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Rate Limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Global Exception Handler ────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled Exception on %s %s: %s", request.method, request.url.path, str(exc))
    return JSONResponse(
        status_code=500,
        content={"status": "error", "message": "Terjadi kesalahan internal sistem."},
    )


# ── Register Routers ────────────────────────────────────────────────
app.include_router(health.router)
app.include_router(ask.router)