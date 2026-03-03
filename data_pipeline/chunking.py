# script utama pipeline chunking: membaca dataset json, memanggil
# document_builder untuk membuat dokumen, lalu menyimpan vektor
# embedding ke qdrant secara bertahap dalam batch.
# kalau prosesnya terhenti, tinggal jalankan ulang untuk resume.

import json
import os
import sys
import time

from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    HnswConfigDiff,
    OptimizersConfigDiff,
)
from langchain_huggingface import HuggingFaceEmbeddings

from document_builder import build_documents, CHUNK_SIZE, CHUNK_OVERLAP

# ─── konstanta konfigurasi ───────────────────────────────────────
DATASET_PATH = "quran_hybrid_dataset.json"
PROGRESS_PATH = "chunking_progress.json"
QDRANT_URL = "http://localhost:6333"
COLLECTION_NAME = "quran_hybrid_collection"
BATCH_SIZE = 64
EMBEDDING_DIM = 768
MODEL_NAME = "intfloat/multilingual-e5-base"


# ─── progress tracking ──────────────────────────────────────────

def load_progress() -> int:
    """Baca file progress untuk resume dari batch terakhir yang berhasil."""
    if os.path.exists(PROGRESS_PATH):
        with open(PROGRESS_PATH, "r") as f:
            return json.load(f).get("uploaded_count", 0)
    return 0


def save_progress(count: int):
    """Simpan jumlah dokumen yang sudah berhasil di-upload."""
    with open(PROGRESS_PATH, "w") as f:
        json.dump({"uploaded_count": count}, f)


def clear_progress():
    """Hapus file progress setelah semua dokumen selesai diproses."""
    if os.path.exists(PROGRESS_PATH):
        os.remove(PROGRESS_PATH)


# ─── qdrant helpers ──────────────────────────────────────────────

def _create_collection(client: QdrantClient):
    """Buat collection baru dengan HNSW config optimal untuk recall tinggi."""
    client.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=VectorParams(size=EMBEDDING_DIM, distance=Distance.COSINE),
        hnsw_config=HnswConfigDiff(
            m=32, ef_construct=200, full_scan_threshold=10000,
        ),
        optimizers_config=OptimizersConfigDiff(indexing_threshold=20000),
    )


def _upload_batches(client, embeddings, documents, uploaded_count):
    """Vektorisasi dan upload dokumen ke Qdrant dalam batch."""
    total_docs = len(documents)
    remaining = documents[uploaded_count:]
    total_batches = (len(remaining) + BATCH_SIZE - 1) // BATCH_SIZE

    print(f"\n5. Memulai vektorisasi & upload ({total_batches} batch "
          f"@ {BATCH_SIZE} dokumen)...\n")

    for batch_idx in range(total_batches):
        start = batch_idx * BATCH_SIZE
        end = min(start + BATCH_SIZE, len(remaining))
        batch = remaining[start:end]
        g_start, g_end = uploaded_count + start, uploaded_count + end

        first_m, last_m = batch[0]["metadata"], batch[-1]["metadata"]
        print(f"  Batch {batch_idx+1}/{total_batches} "
              f"[{g_start+1}–{g_end}/{total_docs}] "
              f"(Surah {first_m['nama_surah']}:{first_m['ayat']}"
              f" – {last_m['nama_surah']}:{last_m['ayat']})")

        try:
            texts = [d["page_content"] for d in batch]
            t0 = time.time()
            vectors = embeddings.embed_documents(texts)
            dt = time.time() - t0

            points = [
                PointStruct(
                    id=d["point_id"], vector=vectors[i],
                    payload={"page_content": d["page_content"],
                             "metadata": d["metadata"]},
                )
                for i, d in enumerate(batch)
            ]
            client.upsert(collection_name=COLLECTION_NAME, points=points)
            save_progress(g_end)
            print(f"    ✓ {dt:.1f}s | {g_end}/{total_docs} "
                  f"({g_end*100//total_docs}%)")

        except KeyboardInterrupt:
            print(f"\n\nDihentikan pada batch {batch_idx+1}. "
                  f"Progress: {g_start}/{total_docs}.")
            sys.exit(0)

        except Exception as e:
            print(f"\n    ✗ ERROR batch {batch_idx+1}: {e}")
            print(f"    Progress: {g_start}/{total_docs}. Jalankan ulang.")
            sys.exit(1)


# ─── pipeline utama ──────────────────────────────────────────────

def main():
    if not os.path.exists(DATASET_PATH):
        print(f"Error: {DATASET_PATH} tidak ditemukan. "
              "Jalankan ingestion.py terlebih dahulu.")
        sys.exit(1)

    print("=" * 60)
    print("CHUNKING PIPELINE v2 — Hybrid Embedding + Metadata")
    print("=" * 60)

    print("\n1. Membaca dataset hybrid MSI Kemenag...")
    with open(DATASET_PATH, "r", encoding="utf-8") as f:
        dataset = json.load(f)
    print(f"   Total ayat mentah: {len(dataset)}")

    print("\n2. Data cleansing & chunking...")
    documents = build_documents(dataset)
    if not documents:
        print("Error: 0 dokumen valid setelah cleansing.")
        sys.exit(1)

    uploaded = load_progress()
    total = len(documents)

    if uploaded >= total:
        print("\nSemua sudah di-upload. Selesai.")
        clear_progress()
        return

    if uploaded > 0:
        print(f"\n   Resume dari {uploaded}/{total}. Sisa: {total-uploaded}.")

    print("\n3. Memuat model embedding (multilingual-e5-base)...")
    embeddings = HuggingFaceEmbeddings(
        model_name=MODEL_NAME,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )
    print("   Model berhasil dimuat.")

    print("\n4. Menghubungkan ke Qdrant...")
    client = QdrantClient(url=QDRANT_URL, timeout=120)

    if uploaded == 0:
        print("   Membuat collection baru (force recreate)...")
        if client.collection_exists(COLLECTION_NAME):
            client.delete_collection(COLLECTION_NAME)
        _create_collection(client)
        print("   Collection dibuat dengan HNSW config optimal.")
    elif not client.collection_exists(COLLECTION_NAME):
        print("   Collection hilang. Mulai ulang dari awal...")
        uploaded = 0
        save_progress(0)
        _create_collection(client)

    _upload_batches(client, embeddings, documents, uploaded)
    clear_progress()

    info = client.get_collection(COLLECTION_NAME)
    print(f"\n{'='*60}")
    print(f"SELESAI! Total vektor: {info.points_count}")
    print(f"  HNSW: m=32, ef_construct=200")
    print(f"  Chunk: size={CHUNK_SIZE}, overlap={CHUNK_OVERLAP}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
