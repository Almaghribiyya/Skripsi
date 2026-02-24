import json
import os
import sys
from langchain_core.documents import Document
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient

def main():
    file_path = "quran_hybrid_dataset.json"
    if not os.path.exists(file_path):
        print(f"Error: Dataset {file_path} tidak ditemukan. Jalankan ingestion_script.py terlebih dahulu.")
        sys.exit(1)

    print("Membaca dataset hybrid MSI Kemenag...")
    with open(file_path, "r", encoding="utf-8") as f:
        dataset = json.load(f)

    # Menggunakan List Comprehension untuk efisiensi pembuatan list
    documents = [
        Document(
            page_content=f"Terjemahan: {item['terjemahan']}\nTafsir Ringkas: {item['tafsir_wajiz']}",
            metadata={
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
        ) for item in dataset
    ]

    print(f"Berhasil memproses {len(documents)} ayat lengkap.")
    print("Memulai Vektorisasi (Embedding) di CPU... Silakan ditunggu.")

    embeddings = HuggingFaceEmbeddings(
        model_name="intfloat/multilingual-e5-base",
        model_kwargs={'device': 'cpu'}, 
        encode_kwargs={'normalize_embeddings': True} 
    )

    # Memasukkan ke Vector Database
    QdrantVectorStore.from_documents(
        documents=documents,
        embedding=embeddings,
        url="http://localhost:6333",
        collection_name="quran_hybrid_collection",
        force_recreate=True 
    )

    print("Selesai! Vector Database berhasil dibangun sempurna di Qdrant.")

if __name__ == "__main__":
    main()