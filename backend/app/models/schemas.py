"""
Pydantic schemas untuk request/response REST API.

Dipisahkan dari business logic agar memenuhi prinsip
Single Responsibility dan mempermudah dokumentasi OpenAPI.
"""

from pydantic import BaseModel, Field


# ── Request Schema ───────────────────────────────────────────────────


class QueryRequest(BaseModel):
    """Payload pertanyaan pengguna ke endpoint /api/ask."""

    pertanyaan: str = Field(
        ...,
        min_length=3,
        max_length=500,
        examples=["Apa itu hari pembalasan?"],
        description="Pertanyaan berbahasa Indonesia tentang Al-Qur'an.",
    )
    top_k: int = Field(
        3,
        ge=1,
        le=5,
        description="Jumlah ayat referensi yang dikembalikan (1-5).",
    )


# ── Response Schemas ─────────────────────────────────────────────────


class ReferensiItem(BaseModel):
    """Satu item referensi ayat Al-Qur'an hasil retrieval."""

    skor_kemiripan: float = Field(
        ..., description="Skor cosine similarity (0–1, semakin tinggi semakin relevan)."
    )
    surah: str = Field(..., description="Nama surah.")
    ayat: int = Field(..., description="Nomor ayat.")
    teks_arab: str = Field(..., description="Teks Arab ayat.")
    terjemahan: str = Field(..., description="Terjemahan bahasa Indonesia.")


class QueryResponse(BaseModel):
    """Respons lengkap dari endpoint /api/ask."""

    status: str = Field("success", description="Status respons: 'success' atau 'error'.")
    pertanyaan: str = Field(..., description="Echo pertanyaan pengguna.")
    jawaban_llm: str = Field(
        ..., description="Jawaban yang dihasilkan oleh LLM berdasarkan konteks ayat."
    )
    referensi: list[ReferensiItem] = Field(
        default_factory=list,
        description="Daftar ayat Al-Qur'an yang menjadi rujukan.",
    )
    skor_tertinggi: float = Field(
        0.0,
        description=(
            "Skor cosine similarity tertinggi dari seluruh hasil retrieval. "
            "Berguna untuk mengukur tingkat relevansi konteks."
        ),
    )


class ErrorResponse(BaseModel):
    """Respons standar untuk error."""

    status: str = Field("error")
    message: str = Field(..., description="Pesan error yang ramah pengguna.")


class HealthResponse(BaseModel):
    """Respons health check."""

    status: str
    message: str
    version: str
