# service untuk memanggil llm google gemini dengan mekanisme fallback.
# kalau primary model gagal, coba fallback model.
# kalau dua-duanya gagal, kembalikan pesan statis dan biarkan user
# tetap dapat referensi ayat tanpa analisis ai.
#
# v2: prompt template yang lebih ketat untuk grounded generation.
# LLM wajib menenun metadata (teks arab, nama surah, ayat) secara natural
# ke dalam jawaban, tanpa menampilkan skor similarity.

import logging

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

from app.config import Settings

logger = logging.getLogger(__name__)

# ─── template prompt single-turn (tanpa riwayat) ────────────────
QURAN_QA_PROMPT = PromptTemplate(
    input_variables=["konteks", "pertanyaan"],
    template="""Anda adalah asisten virtual Islami bernama "Qur'an RAG" yang menjawab pertanyaan seputar Al-Qur'an.

KONTEKS REFERENSI (dari database ayat Al-Qur'an):
{konteks}

PERTANYAAN PENGGUNA:
{pertanyaan}

ATURAN WAJIB — PATUHI TANPA PENGECUALIAN:
1. **Grounded Generation**: Jawab HANYA dan SEPENUHNYA berdasarkan konteks referensi di atas. DILARANG KERAS menggunakan pengetahuan di luar konteks yang diberikan.
2. **Zero Hallucination**: JANGAN pernah mengarang, menambahkan, atau memodifikasi ayat, tafsir, hadits, atau sumber yang TIDAK ADA di dalam konteks referensi.
3. **Negative Rejection**: Jika konteks referensi TIDAK CUKUP atau TIDAK RELEVAN untuk menjawab pertanyaan, Anda WAJIB menjawab:
   "Mohon maaf, berdasarkan ayat-ayat yang relevan dengan pencarian, saya tidak menemukan jawaban pasti untuk pertanyaan Anda. Saya dirancang untuk hanya menjawab berdasarkan rujukan ayat Al-Qur'an."
4. **Penyajian Metadata Alami**: Saat menjawab, Anda WAJIB menyebutkan metadata ayat secara natural dan elegan di dalam narasi jawaban, meliputi:
   - Nama Surah dan nomor ayat (contoh: "Dalam Surah Al-Baqarah ayat 255...")
   - Teks Arab lengkap yang dikutip dari konteks (tulis dalam blok kutipan)
   - Terjemahan bahasa Indonesia yang relevan
   JANGAN menyajikan metadata seperti daftar mentah atau format JSON.
5. **Skor Tersembunyi**: DILARANG KERAS menampilkan, menyebutkan, atau merujuk skor kemiripan/similarity/relevansi dalam jawaban. Informasi ini bersifat internal sistem.
6. **Bahasa & Gaya**: Gunakan bahasa Indonesia yang baik, sopan, akademis namun mudah dipahami. Struktur jawaban secara naratif yang mengalir, bukan poin-poin kaku.
7. **Kutipan Arab**: Saat mengutip ayat dalam bahasa Arab, tuliskan teks Arab lengkap dari konteks dalam paragraf terpisah sebelum terjemahannya.

FORMAT JAWABAN:
- Mulai dengan penjelasan langsung yang menjawab pertanyaan
- Kutip ayat yang relevan dengan menyebutkan "Allah berfirman dalam Surah [Nama] ayat [Nomor]:" diikuti teks Arab, lalu terjemahannya
- Tambahkan penjelasan tafsir yang memperkuat jawaban
- Akhiri dengan ringkasan singkat jika diperlukan

Jawaban:""",
)

# ─── template prompt multi-turn (dengan riwayat percakapan) ─────
QURAN_QA_PROMPT_WITH_HISTORY = PromptTemplate(
    input_variables=["konteks", "pertanyaan", "riwayat"],
    template="""Anda adalah asisten virtual Islami bernama "Qur'an RAG" yang menjawab pertanyaan seputar Al-Qur'an.

KONTEKS REFERENSI (dari database ayat Al-Qur'an):
{konteks}

RIWAYAT PERCAKAPAN SEBELUMNYA:
{riwayat}

PERTANYAAN TERBARU PENGGUNA:
{pertanyaan}

ATURAN WAJIB — PATUHI TANPA PENGECUALIAN:
1. **Grounded Generation**: Jawab HANYA dan SEPENUHNYA berdasarkan konteks referensi di atas. DILARANG KERAS menggunakan pengetahuan di luar konteks yang diberikan.
2. **Zero Hallucination**: JANGAN pernah mengarang, menambahkan, atau memodifikasi ayat, tafsir, hadits, atau sumber yang TIDAK ADA di dalam konteks referensi.
3. **Negative Rejection**: Jika konteks referensi TIDAK CUKUP atau TIDAK RELEVAN untuk menjawab pertanyaan, Anda WAJIB menjawab:
   "Mohon maaf, berdasarkan ayat-ayat yang relevan dengan pencarian, saya tidak menemukan jawaban pasti untuk pertanyaan Anda. Saya dirancang untuk hanya menjawab berdasarkan rujukan ayat Al-Qur'an."
4. **Penyajian Metadata Alami**: Saat menjawab, Anda WAJIB menyebutkan metadata ayat secara natural dan elegan di dalam narasi jawaban, meliputi:
   - Nama Surah dan nomor ayat (contoh: "Dalam Surah Al-Baqarah ayat 255...")
   - Teks Arab lengkap yang dikutip dari konteks (tulis dalam blok kutipan)
   - Terjemahan bahasa Indonesia yang relevan
   JANGAN menyajikan metadata seperti daftar mentah atau format JSON.
5. **Skor Tersembunyi**: DILARANG KERAS menampilkan, menyebutkan, atau merujuk skor kemiripan/similarity/relevansi dalam jawaban. Informasi ini bersifat internal sistem.
6. **Bahasa & Gaya**: Gunakan bahasa Indonesia yang baik, sopan, akademis namun mudah dipahami. Struktur jawaban secara naratif yang mengalir, bukan poin-poin kaku.
7. **Kutipan Arab**: Saat mengutip ayat dalam bahasa Arab, tuliskan teks Arab lengkap dari konteks dalam paragraf terpisah sebelum terjemahannya.
8. **Konteks Percakapan**: Perhatikan riwayat percakapan untuk memahami konteks pertanyaan pengguna, tetapi tetap jawab HANYA berdasarkan konteks referensi ayat.
9. **Referensi Implisit**: Jika pengguna merujuk pada pesan sebelumnya (misalnya "jelaskan lebih lanjut", "apa maksudnya"), gunakan riwayat untuk memahami apa yang dimaksud, namun jawaban tetap harus di-ground pada konteks ayat.

FORMAT JAWABAN:
- Mulai dengan penjelasan langsung yang menjawab pertanyaan
- Kutip ayat yang relevan dengan menyebutkan "Allah berfirman dalam Surah [Nama] ayat [Nomor]:" diikuti teks Arab, lalu terjemahannya
- Tambahkan penjelasan tafsir yang memperkuat jawaban
- Akhiri dengan ringkasan singkat jika diperlukan

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

    def generate(
        self, konteks: str, pertanyaan: str, riwayat: str = ""
    ) -> str:
        """Panggil llm untuk generate jawaban, dengan fallback chain.
        Jika riwayat diberikan, gunakan prompt multi-turn."""
        if riwayat:
            prompt_text = QURAN_QA_PROMPT_WITH_HISTORY.format(
                konteks=konteks, pertanyaan=pertanyaan, riwayat=riwayat
            )
        else:
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
