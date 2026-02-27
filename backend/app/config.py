# file ini jadi satu-satunya tempat konfigurasi di seluruh backend.
# semua variabel lingkungan dibaca dari file .env di root folder backend.

import os
from pathlib import Path
from functools import lru_cache

from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Semua pengaturan aplikasi dimuat dari environment variable.
    Pakai pydantic settings supaya otomatis validasi tipe data."""

    # identitas aplikasi yang tampil di halaman docs
    app_title: str = "Pustaka Digital Al-Qur'an API (RAG)"
    app_description: str = (
        "REST API untuk Sistem Tanya Jawab Al-Qur'an "
        "berbasis Retrieval-Augmented Generation."
    )
    app_version: str = "1.0.0"

    # koneksi ke qdrant vector database
    qdrant_url: str = Field("http://localhost:6333", alias="QDRANT_URL")
    qdrant_collection: str = Field(
        "quran_hybrid_collection", alias="QDRANT_COLLECTION"
    )

    # model embedding untuk mengubah teks jadi vektor
    embedding_model: str = Field(
        "intfloat/multilingual-e5-base", alias="EMBEDDING_MODEL"
    )
    embedding_device: str = Field("cpu", alias="EMBEDDING_DEVICE")

    # konfigurasi llm google gemini untuk generate jawaban
    gemini_api_key: str = Field("", alias="GEMINI_API_KEY")
    llm_primary_model: str = Field("gemini-2.5-flash", alias="LLM_PRIMARY_MODEL")
    llm_fallback_model: str = Field("gemini-2.0-flash", alias="LLM_FALLBACK_MODEL")
    llm_temperature: float = Field(0.3, alias="LLM_TEMPERATURE")

    # skor minimum cosine similarity untuk dianggap relevan.
    # kalau di bawah ambang ini, sistem langsung tolak tanpa panggil llm.
    similarity_threshold: float = Field(
        0.45,
        alias="SIMILARITY_THRESHOLD",
        description=(
            "Skor minimum cosine similarity. "
            "Dokumen di bawah ambang ini dianggap tidak cukup relevan."
        ),
    )

    # batas jumlah request per menit dari satu ip
    rate_limit: str = Field("10/minute", alias="RATE_LIMIT")

    # path ke file credential firebase dan toggle autentikasi.
    # set auth_enabled false kalau mau development tanpa firebase.
    firebase_credentials_path: str = Field("", alias="FIREBASE_CREDENTIALS_PATH")
    auth_enabled: bool = Field(
        True,
        alias="AUTH_ENABLED",
        description="Nonaktifkan untuk development tanpa Firebase.",
    )

    # daftar origin yang diizinkan untuk cors
    cors_origins: list[str] = Field(default=["*"], alias="CORS_ORIGINS")

    model_config = {
        "env_file": str(Path(__file__).resolve().parent.parent / ".env"),
        "env_file_encoding": "utf-8",
        "extra": "ignore",
        "populate_by_name": True,
    }


@lru_cache()
def get_settings() -> Settings:
    """Ambil instance settings yang sudah di-cache supaya tidak buat ulang."""
    return Settings()
