from fastapi import FastAPI
from pydantic import BaseModel
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

app = FastAPI(title="Quran RAG API Backend")

# 1. Inisialisasi Model AI
print("Memuat model NLP...")
embeddings = HuggingFaceEmbeddings(
    model_name="intfloat/multilingual-e5-base",
    model_kwargs={'device': 'cpu'},
    encode_kwargs={'normalize_embeddings': True}
)

# 2. Hubungkan ke Qdrant Docker
client = QdrantClient(url="http://localhost:6333")
vector_store = QdrantVectorStore(
    client=client,
    collection_name="quran_hybrid_collection",
    embedding=embeddings,
)

# 3. Struktur Data Permintaan (Request)
class QueryRequest(BaseModel):
    pertanyaan: str
    top_k: int = 3  

# 4. Halaman Depan (Root)
@app.get("/")
async def root():
    return {
        "status": "aktif",
        "pesan": "Selamat datang di API Sistem Tanya Jawab Al-Qur'an (RAG). Kunjungi /docs untuk menguji API."
    }

# 5. Endpoint Pencarian (Retrieval)
@app.post("/api/search")
async def search_quran(request: QueryRequest):
    # Mencari vektor ayat yang paling mirip
    hasil_pencarian = vector_store.similarity_search_with_score(
        query=request.pertanyaan, 
        k=request.top_k
    )
    
    # Menyusun hasil 
    respons_data = []
    for doc, score in hasil_pencarian:
        respons_data.append({
            "skor_kemiripan": score,
            "surah": doc.metadata.get("nama_surah"),
            "ayat": doc.metadata.get("ayat"),
            "halaman": doc.metadata.get("halaman"),
            "teks_arab": doc.metadata.get("teks_arab"),
            "terjemahan": doc.metadata.get("terjemahan"),
            "tafsir_wajiz": doc.metadata.get("tafsir_wajiz"),
            "tafsir_tahlili": doc.metadata.get("tafsir_tahlili")
        })
        
    return {
        "pertanyaan": request.pertanyaan,
        "hasil": respons_data
    }