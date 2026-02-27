"""
LLMService — Tanggung jawab tunggal: memanggil LLM dengan mekanisme fallback.

Arsitektur fallback bertingkat:
  1. Primary LLM  (Gemini 2.5 Flash) — model terbaru, kualitas terbaik.
  2. Fallback LLM (Gemini 2.0 Flash) — model stabil sebagai cadangan.
  3. Retrieval-Only Mode — jika semua LLM gagal, kembalikan pesan fallback statis
     dan biarkan layer atasnya mengembalikan referensi ayat tanpa analisis AI.

Keputusan arsitektural: Menggunakan LLM lokal (Ollama, llama.cpp) tidak
memungkinkan secara spesifikasi perangkat keras (sesuai catatan sidang).
Oleh karena itu, dua instance Gemini yang berbeda digunakan sebagai primary
dan fallback untuk meminimalkan risiko downtime API.
"""

import logging

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

from app.config import Settings

logger = logging.getLogger(__name__)

# ── Prompt Template (Grounded Generation + Negative Rejection) ────────────

QURAN_QA_PROMPT = PromptTemplate(
    input_variables=["konteks", "pertanyaan"],
    template="""Anda adalah asisten virtual Islami yang bertugas menjawab pertanyaan berdasarkan Al-Qur'an.
Gunakan HANYA konteks (ayat dan tafsir) di bawah ini untuk menjawab pertanyaan.

Konteks:
{konteks}

Pertanyaan: {pertanyaan}

ATURAN KETAT (Grounded Generation & Negative Rejection):
1. Jawab HANYA berdasarkan konteks di atas. DILARANG menggunakan pengetahuan di luar konteks.
2. Jika jawaban TIDAK ADA atau TIDAK CUKUP di dalam konteks yang diberikan, Anda WAJIB menjawab:
   "Mohon maaf, berdasarkan ayat-ayat yang relevan dengan pencarian, saya tidak menemukan jawaban pasti untuk pertanyaan Anda. Saya dirancang untuk hanya menjawab berdasarkan rujukan ayat Al-Qur'an."
3. JANGAN pernah mengarang ayat, tafsir, hadits, atau sumber yang tidak ada di konteks.
4. Sebutkan rujukan surah dan nomor ayat yang relevan saat menjawab.
5. Gunakan bahasa Indonesia yang baik, sopan, dan mudah dipahami.

Jawaban:""",
)

FALLBACK_MESSAGE = (
    "Mohon maaf, mesin penalaran AI kami sedang mengalami gangguan. "
    "Namun, berikut adalah ayat-ayat yang paling relevan dengan "
    "pertanyaan Anda yang berhasil kami temukan:"
)


class LLMService:
    """Mengelola panggilan LLM dengan mekanisme fallback bertingkat."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

        # Primary LLM
        self._primary = ChatGoogleGenerativeAI(
            model=settings.llm_primary_model,
            google_api_key=settings.gemini_api_key,
            temperature=settings.llm_temperature,
        )
        logger.info("LLM Primary initialized: %s", settings.llm_primary_model)

        # Fallback LLM (model berbeda untuk redundansi)
        self._fallback = ChatGoogleGenerativeAI(
            model=settings.llm_fallback_model,
            google_api_key=settings.gemini_api_key,
            temperature=settings.llm_temperature,
        )
        logger.info("LLM Fallback initialized: %s", settings.llm_fallback_model)

    def generate(self, konteks: str, pertanyaan: str) -> str:
        """
        Memanggil LLM untuk menghasilkan jawaban.

        Fallback chain:
          primary → fallback → static message.

        Returns:
            Jawaban string dari LLM atau pesan fallback statis.
        """
        prompt_text = QURAN_QA_PROMPT.format(
            konteks=konteks, pertanyaan=pertanyaan
        )

        # Tahap 1: Primary LLM
        try:
            response = self._primary.invoke(prompt_text)
            logger.info("LLM Primary berhasil menjawab.")
            return response.content
        except Exception as e:
            logger.warning("LLM Primary gagal: %s. Mencoba fallback...", str(e))

        # Tahap 2: Fallback LLM
        try:
            response = self._fallback.invoke(prompt_text)
            logger.info("LLM Fallback berhasil menjawab.")
            return response.content
        except Exception as e:
            logger.error("LLM Fallback juga gagal: %s. Menggunakan mode retrieval-only.", str(e))

        # Tahap 3: Retrieval-Only Mode (semua LLM gagal)
        return FALLBACK_MESSAGE
