import json
from langchain_core.documents import Document
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

print("Membaca dataset hybrid MSI Kemenag yang sudah disinkronisasi...")
with open("quran_hybrid_dataset.json", "r", encoding="utf-8") as f:
    dataset = json.load(f)

documents = []
for item in dataset:
    # Dense Vector: Hanya Terjemahan & Wajiz untuk akurasi pencarian Semantik
    teks_pencarian = f"Terjemahan: {item['terjemahan']}\nTafsir Ringkas: {item['tafsir_wajiz']}"
    
    metadata = {
        "surah": item["surah"],        
        "ayat": item["ayat"],          
        "juz": item["juz"],
        "halaman": item["halaman"],
        "nama_surah": item["nama_surah"],
        "arti_surah": item["arti_surah"],
        "kategori_surah": item["kategori_surah"],
        "teks_arab": item["teks_arab"],
        "transliterasi": item["transliterasi"],
        "terjemahan": item["terjemahan"], 
        "catatan_kaki": item["catatan_kaki"],
        "tafsir_wajiz": item["tafsir_wajiz"],
        "tafsir_tahlili": item["tafsir_tahlili"] 
    }
    documents.append(Document(page_content=teks_pencarian, metadata=metadata))

print(f"Berhasil memproses {len(documents)} ayat lengkap.")
print("Memulai Vektorisasi (Embedding) di CPU... Silakan ditunggu.")

# Menggunakan model Embedding sesuai standar penelitian Anda
embeddings = HuggingFaceEmbeddings(
    model_name="intfloat/multilingual-e5-base",
    model_kwargs={'device': 'cpu'}, 
    encode_kwargs={'normalize_embeddings': True} 
)

# Hubungkan ke Docker Qdrant (Pastikan container sudah berjalan di port 6333)
client = QdrantClient(url="http://localhost:6333")
collection_name = "quran_hybrid_collection"

vector_store = QdrantVectorStore.from_documents(
    documents=documents,
    embedding=embeddings,
    url="http://localhost:6333",
    collection_name=collection_name,
    force_recreate=True 
)

print("Selesai! Vector Database berhasil dibangun sempurna di Qdrant.")