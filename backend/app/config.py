"""
Konfigurasi terpusat menggunakan Pydantic Settings.

Semua variabel lingkungan dimuat dari file .env di root backend/.
Prinsip: Single Source of Truth untuk semua konfigurasi aplikasi.
"""

import os
from pathlib import Path
from functools import lru_cache

from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Immutable application settings loaded from environment variables."""

    # ── Identitas Aplikasi ────────────────────────────────────────────
    app_title: str = "Pustaka Digital Al-Qur'an API (RAG)"
    app_description: str = (
        "REST API untuk Sistem Tanya Jawab Al-Qur'an "
        "berbasis Retrieval-Augmented Generation."
    )
    app_version: str = "1.0.0"

    # ── Qdrant Vector Database ────────────────────────────────────────
    qdrant_url: str = Field("http://localhost:6333", alias="QDRANT_URL")
    qdrant_collection: str = Field(
        "quran_hybrid_collection", alias="QDRANT_COLLECTION"
    )

    # ── Embedding Model ──────────────────────────────────────────────
    embedding_model: str = Field(
        "intfloat/multilingual-e5-base", alias="EMBEDDING_MODEL"
    )
    embedding_device: str = Field("cpu", alias="EMBEDDING_DEVICE")

    # ── LLM (Google Gemini) ──────────────────────────────────────────
    gemini_api_key: str = Field("", alias="GEMINI_API_KEY")
    llm_primary_model: str = Field("gemini-2.5-flash", alias="LLM_PRIMARY_MODEL")
    llm_fallback_model: str = Field("gemini-2.0-flash", alias="LLM_FALLBACK_MODEL")
    llm_temperature: float = Field(0.3, alias="LLM_TEMPERATURE")

    # ── RAG Tuning ───────────────────────────────────────────────────
    similarity_threshold: float = Field(
        0.45,
        alias="SIMILARITY_THRESHOLD",
        description=(
            "Skor minimum cosine similarity. "
            "Dokumen di bawah ambang ini dianggap tidak cukup relevan."
        ),
    )

    # ── Rate Limiting ────────────────────────────────────────────────
    rate_limit: str = Field("10/minute", alias="RATE_LIMIT")

    # ── Firebase Authentication ──────────────────────────────────────
    firebase_credentials_path: str = Field("", alias="FIREBASE_CREDENTIALS_PATH")
    auth_enabled: bool = Field(
        True,
        alias="AUTH_ENABLED",
        description="Nonaktifkan untuk development tanpa Firebase.",
    )

    # ── CORS ─────────────────────────────────────────────────────────
    cors_origins: list[str] = Field(default=["*"], alias="CORS_ORIGINS")

    model_config = {
        "env_file": str(Path(__file__).resolve().parent.parent / ".env"),
        "env_file_encoding": "utf-8",
        "extra": "ignore",
        "populate_by_name": True,
    }


@lru_cache()
def get_settings() -> Settings:
    """Mengembalikan instance Settings yang di-cache (singleton)."""
    return Settings()
