# pydantic schema untuk request dan response rest api.
# dipisahkan dari business logic supaya file tetap fokus
# dan dokumentasi openapi otomatis terbentuk dari sini.

from pydantic import BaseModel, Field


# schema untuk request masuk dari user

class RiwayatItem(BaseModel):
    """Satu item riwayat percakapan sebelumnya."""

    peran: str = Field(
        ...,
        description="Peran pengirim: 'user' atau 'ai'.",
        examples=["user"],
    )
    konten: str = Field(
        ...,
        max_length=2000,
        description="Isi pesan.",
    )


class QueryRequest(BaseModel):
    """Payload pertanyaan yang dikirim user ke endpoint tanya jawab."""

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
    riwayat_percakapan: list[RiwayatItem] = Field(
        default_factory=list,
        max_length=10,
        description=(
            "Riwayat percakapan sebelumnya untuk konteks memori. "
            "Maksimal 10 pesan terakhir (5 giliran)."
        ),
    )


# schema untuk response yang dikirim balik ke user

class ReferensiItem(BaseModel):
    """Satu item referensi ayat yang ditemukan dari vector search."""

    skor_kemiripan: float = Field(
        ..., description="Skor cosine similarity (0–1, semakin tinggi semakin relevan)."
    )
    surah: str = Field(..., description="Nama surah.")
    ayat: int = Field(..., description="Nomor ayat.")
    teks_arab: str = Field(..., description="Teks Arab ayat.")
    terjemahan: str = Field(..., description="Terjemahan bahasa Indonesia.")


class QueryResponse(BaseModel):
    """Response lengkap dari endpoint tanya jawab berisi jawaban dan referensi."""

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
    """Response standar kalau terjadi error."""

    status: str = Field("error")
    message: str = Field(..., description="Pesan error yang ramah pengguna.")


class HealthResponse(BaseModel):
    """Response dari endpoint health check."""

    status: str
    message: str
    version: str
