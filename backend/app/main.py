# file utama aplikasi backend. tanggung jawabnya cuma:
# membuat instance fastapi, pasang middleware, daftarkan router,
# dan inisialisasi service saat startup lewat lifespan.
# semua business logic ada di layer service dan router.

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config import get_settings
from app.dependencies import init_services
from app.routers import health, ask
from app.routers.ask import limiter

# setup logging supaya output di terminal rapi dan mudah dibaca
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Muat semua resource berat saat startup seperti model embedding,
    koneksi llm, dan qdrant. Pakai lifespan supaya terkontrol dan
    bisa di-log dengan jelas kapan selesainya."""
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

    yield  # aplikasi berjalan di sini

    logger.info("Shutting down application.")


# baca settings dan buat instance aplikasi
settings = get_settings()

# rate limiter: pakai instance tunggal dari modul ask supaya
# state tracking request tidak terpecah di dua objek berbeda.

app = FastAPI(
    title=settings.app_title,
    description=settings.app_description,
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# pasang rate limiter ke state aplikasi
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# pasang cors supaya frontend bisa akses api dari domain berbeda
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Tangkap semua error yang tidak tertangani supaya user tetap
    dapat response json yang rapi, bukan html error bawaan."""
    logger.error("Unhandled Exception on %s %s: %s", request.method, request.url.path, str(exc))
    return JSONResponse(
        status_code=500,
        content={"status": "error", "message": "Terjadi kesalahan internal sistem."},
    )


# daftarkan semua router ke aplikasi
app.include_router(health.router)
app.include_router(ask.router)