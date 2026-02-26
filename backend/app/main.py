import os
import logging
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from pathlib import Path
from dotenv import load_dotenv
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import PromptTemplate

# Memuat variabel dari backend/.env
_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)

# Konfigurasi Logger dasar
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address)
app = FastAPI(
    title="Pustaka Digital Al-Qur'an API (RAG)",
    description="REST API untuk Sistem Tanya Jawab Al-Qur'an (Retrieval-Augmented Generation).",
    version="1.0.0"
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global Exception: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"status": "error", "message": "Terjadi kesalahan internal sistem."},
    )

class QueryRequest(BaseModel):
    pertanyaan: str = Field(..., examples=["Apa itu hari pembalasan?"])
    top_k: int = Field(3, ge=1, le=5, description="Jumlah referensi (1-5)")

class ReferensiItem(BaseModel):
    skor_kemiripan: float
    surah: str
    ayat: int
    teks_arab: str
    terjemahan: str

class QueryResponse(BaseModel):
    status: str
    pertanyaan: str
    jawaban_llm: str
    referensi: list[ReferensiItem]

# Inisialisasi Model
embeddings = HuggingFaceEmbeddings(
    model_name="intfloat/multilingual-e5-base",
    model_kwargs={'device': 'cpu'},
    encode_kwargs={'normalize_embeddings': True}
)

qdrant_client = QdrantClient(url="http://localhost:6333")
vector_store = QdrantVectorStore(
    client=qdrant_client,
    collection_name="quran_hybrid_collection",
    embedding=embeddings,
)

llm_primary = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash",
    google_api_key=os.getenv("GEMINI_API_KEY"),
    temperature=0.3 
)

prompt_template = PromptTemplate(
    input_variables=["konteks", "pertanyaan"],
    template="""Anda adalah asisten virtual Islami yang bertugas menjawab pertanyaan berdasarkan Al-Qur'an.
Gunakan HANYA konteks (ayat dan tafsir) di bawah ini untuk menjawab pertanyaan. 

Konteks:
{konteks}

Pertanyaan: {pertanyaan}

ATURAN KETAT (Negative Rejection):
1. Jika jawaban TIDAK ADA di dalam konteks yang diberikan, Anda WAJIB menjawab: "Mohon maaf, berdasarkan ayat-ayat yang relevan dengan pencarian, saya tidak menemukan jawaban pasti untuk pertanyaan Anda. Saya dirancang untuk hanya menjawab berdasarkan rujukan ayat Al-Qur'an."
2. Jangan pernah mengarang ayat, tafsir, atau menggunakan pengetahuan di luar konteks di atas.
3. Sebutkan rujukan surah dan ayatnya saat menjawab.

Jawaban:"""
)

@app.post("/api/ask", response_model=QueryResponse, tags=["Q&A"])
@limiter.limit("10/minute") 
async def ask_quran(request: Request, payload: QueryRequest):
    # Tahap A: Retrieval
    hasil_pencarian = vector_store.similarity_search_with_score(
        query=payload.pertanyaan, 
        k=payload.top_k
    )
    
    if not hasil_pencarian:
        return QueryResponse(
            status="success", 
            pertanyaan=payload.pertanyaan,
            jawaban_llm="Sistem belum memiliki data ayat yang cukup.", 
            referensi=[]
        )

    # Optimasi: Menggunakan List Comprehension dan Join untuk merakit data
    referensi_data = []
    konteks_list = []
    
    for doc, score in hasil_pencarian:
        meta = doc.metadata
        nama_surah = meta.get("nama_surah", "Tidak Diketahui")
        ayat = meta.get("ayat", 0)
        terjemahan = meta.get("terjemahan", "")
        tafsir = meta.get("tafsir_wajiz", "")
        
        konteks_list.append(f"Surah {nama_surah} Ayat {ayat}:\nTerjemahan: {terjemahan}\nTafsir: {tafsir}")
        
        referensi_data.append(ReferensiItem(
            skor_kemiripan=score,
            surah=nama_surah,
            ayat=ayat,
            teks_arab=meta.get("teks_arab", ""),
            terjemahan=terjemahan
        ))
        
    konteks_teks = "\n\n".join(konteks_list)

    # Tahap B: Generation
    try:
        prompt_final = prompt_template.format(konteks=konteks_teks, pertanyaan=payload.pertanyaan)
        response = llm_primary.invoke(prompt_final)
        jawaban_llm = response.content
    except Exception as e:
        logger.error(f"LLM API Error: {str(e)}")
        jawaban_llm = "Mohon maaf, mesin penalaran AI kami sedang mengalami gangguan (Fallback Mode). Namun, berikut adalah ayat-ayat yang paling relevan dengan pertanyaan Anda yang berhasil kami temukan:"

    return QueryResponse(
        status="success",
        pertanyaan=payload.pertanyaan,
        jawaban_llm=jawaban_llm,
        referensi=referensi_data
    )

@app.get("/", tags=["Health Check"])
async def root():
    return {"message": "Quran RAG Backend is running. Kunjungi /docs untuk dokumentasi REST API."}