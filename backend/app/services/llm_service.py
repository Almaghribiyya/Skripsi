# service untuk memanggil llm google gemini dengan mekanisme fallback.
# kalau primary model gagal, coba fallback model.
# kalau dua-duanya gagal, kembalikan pesan statis dan biarkan user
# tetap dapat referensi ayat tanpa analisis ai.

import logging

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

from app.config import Settings

logger = logging.getLogger(__name__)

# template prompt untuk grounded generation dan negative rejection.
# llm hanya boleh jawab berdasarkan konteks yang diberikan.
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

# pesan kalau semua llm gagal, user tetap dapat ayat referensi
FALLBACK_MESSAGE = (
    "Mohon maaf, mesin penalaran AI kami sedang mengalami gangguan. "
    "Namun, berikut adalah ayat-ayat yang paling relevan dengan "
    "pertanyaan Anda yang berhasil kami temukan:"
)


class LLMService:
    """Panggilan LLM dengan fallback bertingkat: primary, fallback, statis."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

        # model utama, biasanya gemini versi terbaru
        self._primary = ChatGoogleGenerativeAI(
            model=settings.llm_primary_model,
            google_api_key=settings.gemini_api_key,
            temperature=settings.llm_temperature,
        )
        logger.info("LLM Primary initialized: %s", settings.llm_primary_model)

        # model cadangan, dipakai kalau primary gagal
        self._fallback = ChatGoogleGenerativeAI(
            model=settings.llm_fallback_model,
            google_api_key=settings.gemini_api_key,
            temperature=settings.llm_temperature,
        )
        logger.info("LLM Fallback initialized: %s", settings.llm_fallback_model)

    def generate(self, konteks: str, pertanyaan: str) -> str:
        """Panggil llm untuk generate jawaban, dengan fallback chain."""
        prompt_text = QURAN_QA_PROMPT.format(
            konteks=konteks, pertanyaan=pertanyaan
        )

        # coba dulu pakai primary model
        try:
            response = self._primary.invoke(prompt_text)
            logger.info("LLM Primary berhasil menjawab.")
            return response.content
        except Exception as e:
            logger.warning("LLM Primary gagal: %s. Mencoba fallback...", str(e))

        # primary gagal, coba fallback model
        try:
            response = self._fallback.invoke(prompt_text)
            logger.info("LLM Fallback berhasil menjawab.")
            return response.content
        except Exception as e:
            logger.error("LLM Fallback juga gagal: %s. Menggunakan mode retrieval-only.", str(e))

        # semua llm gagal, kembalikan pesan statis
        return FALLBACK_MESSAGE
