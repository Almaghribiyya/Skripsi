import json
import os
import sys
import time
import uuid
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from langchain_huggingface import HuggingFaceEmbeddings

# ── Konfigurasi ─────────────────────────────────────────────
DATASET_PATH     = "quran_hybrid_dataset.json"
PROGRESS_PATH    = "chunking_progress.json"
QDRANT_URL       = "http://localhost:6333"
COLLECTION_NAME  = "quran_hybrid_collection"
BATCH_SIZE       = 100          # Jumlah ayat per batch
EMBEDDING_DIM    = 768          # Dimensi multilingual-e5-base
MODEL_NAME       = "intfloat/multilingual-e5-base"


def load_progress() -> int:
    """Membaca progress terakhir (jumlah dokumen yang sudah di-upload)."""
    if os.path.exists(PROGRESS_PATH):
        with open(PROGRESS_PATH, "r") as f:
            data = json.load(f)
            return data.get("uploaded_count", 0)
    return 0


def save_progress(count: int):
    """Menyimpan progress ke file JSON."""
    with open(PROGRESS_PATH, "w") as f:
        json.dump({"uploaded_count": count}, f)


def clear_progress():
    """Menghapus file progress setelah selesai."""
    if os.path.exists(PROGRESS_PATH):
        os.remove(PROGRESS_PATH)


def main():
    # ── 1. Validasi dataset ─────────────────────────────────
    if not os.path.exists(DATASET_PATH):
        print(f"Error: Dataset {DATASET_PATH} tidak ditemukan. "
              "Jalankan ingestion.py terlebih dahulu.")
        sys.exit(1)

    print("Membaca dataset hybrid MSI Kemenag...")
    with open(DATASET_PATH, "r", encoding="utf-8") as f:
        dataset = json.load(f)

    total_docs = len(dataset)
    print(f"Total ayat dalam dataset: {total_docs}")

    # ── 2. Cek progress sebelumnya ──────────────────────────
    uploaded_count = load_progress()

    if uploaded_count >= total_docs:
        print("Semua dokumen sudah di-upload sebelumnya. Tidak ada yang perlu diproses.")
        clear_progress()
        return

    if uploaded_count > 0:
        print(f"Melanjutkan dari progress sebelumnya: {uploaded_count}/{total_docs} "
              f"sudah ter-upload.")
        print(f"Sisa: {total_docs - uploaded_count} dokumen.")
    else:
        print("Memulai proses dari awal...")

    # ── 3. Inisialisasi embedding model ─────────────────────
    print("Memuat model embedding (multilingual-e5-base) di CPU...")
    embeddings = HuggingFaceEmbeddings(
        model_name=MODEL_NAME,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )

    # ── 4. Inisialisasi Qdrant client ───────────────────────
    client = QdrantClient(url=QDRANT_URL)

    # Buat collection baru hanya jika mulai dari awal
    if uploaded_count == 0:
        print("Membuat collection baru di Qdrant (force recreate)...")
        client.recreate_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(
                size=EMBEDDING_DIM,
                distance=Distance.COSINE,
            ),
        )
    else:
        # Pastikan collection masih ada untuk resume
        collections = [c.name for c in client.get_collections().collections]
        if COLLECTION_NAME not in collections:
            print("Collection tidak ditemukan di Qdrant. Memulai ulang dari awal...")
            uploaded_count = 0
            save_progress(0)
            client.recreate_collection(
                collection_name=COLLECTION_NAME,
                vectors_config=VectorParams(
                    size=EMBEDDING_DIM,
                    distance=Distance.COSINE,
                ),
            )

    # ── 5. Proses per batch dengan progress tracking ────────
    remaining_data = dataset[uploaded_count:]
    total_batches = (len(remaining_data) + BATCH_SIZE - 1) // BATCH_SIZE

    print(f"\nMemulai vektorisasi & upload dalam {total_batches} batch "
          f"(@ {BATCH_SIZE} dokumen)...\n")

    for batch_idx in range(total_batches):
        batch_start = batch_idx * BATCH_SIZE
        batch_end = min(batch_start + BATCH_SIZE, len(remaining_data))
        batch_data = remaining_data[batch_start:batch_end]

        global_start = uploaded_count + batch_start
        global_end = uploaded_count + batch_end

        # Info surah dalam batch ini
        surah_range = f"Surah {batch_data[0]['surah']}:{batch_data[0]['ayat']}"
        surah_range += f" – {batch_data[-1]['surah']}:{batch_data[-1]['ayat']}"

        print(f"  Batch {batch_idx + 1}/{total_batches} "
              f"[{global_start + 1}–{global_end}/{total_docs}] "
              f"({surah_range})")

        try:
            # Siapkan teks untuk embedding
            texts = [
                f"Terjemahan: {item['terjemahan']}\nTafsir Ringkas: {item['tafsir_wajiz']}"
                for item in batch_data
            ]

            # Generate embeddings
            t0 = time.time()
            vectors = embeddings.embed_documents(texts)
            embed_time = time.time() - t0

            # Siapkan points untuk Qdrant
            points = []
            for i, item in enumerate(batch_data):
                points.append(PointStruct(
                    id=str(uuid.uuid5(uuid.NAMESPACE_DNS,
                                      f"quran-{item['surah']}-{item['ayat']}")),
                    vector=vectors[i],
                    payload={
                        "page_content": texts[i],
                        "metadata": {
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
                            "tafsir_tahlili": item["tafsir_tahlili"],
                        },
                    },
                ))

            # Upload ke Qdrant
            client.upsert(collection_name=COLLECTION_NAME, points=points)

            # Simpan progress setelah batch berhasil
            new_count = global_end
            save_progress(new_count)

            print(f"    ✓ Embedding: {embed_time:.1f}s | "
                  f"Upload OK | Progress: {new_count}/{total_docs} "
                  f"({new_count * 100 // total_docs}%)")

        except KeyboardInterrupt:
            print(f"\n\nProses dihentikan oleh pengguna pada batch {batch_idx + 1}.")
            print(f"Progress tersimpan: {uploaded_count + batch_start}/{total_docs} dokumen.")
            print("Jalankan ulang chunking.py untuk melanjutkan.")
            sys.exit(0)

        except Exception as e:
            print(f"\n    ✗ ERROR pada batch {batch_idx + 1}: {e}")
            print(f"    Progress tersimpan: {uploaded_count + batch_start}/{total_docs} dokumen.")
            print("    Jalankan ulang chunking.py untuk melanjutkan dari batch ini.")
            sys.exit(1)

    # ── 6. Selesai ──────────────────────────────────────────
    clear_progress()
    
    # Verifikasi jumlah dokumen di Qdrant
    info = client.get_collection(COLLECTION_NAME)
    print(f"\nSelesai! Vector Database berhasil dibangun di Qdrant.")
    print(f"Total vektor di collection: {info.points_count}")
    print(f"File progress ({PROGRESS_PATH}) telah dihapus.")


if __name__ == "__main__":
    main()