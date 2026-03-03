# script ini bertanggung jawab untuk mengubah dataset json hasil akuisisi
# menjadi vektor embedding lalu menyimpannya ke qdrant secara bertahap.
# kalau prosesnya terhenti di tengah jalan, tinggal jalankan ulang dan
# dia akan otomatis lanjut dari batch terakhir yang berhasil.
#
# PERUBAHAN v2:
# - data cleansing: skip surah 7, 17, 26 (metadata tidak lengkap)
# - page_content berisi gabungan terjemahan + keyword tematik + tafsir
# - tafsir_tahlili yang panjang dipecah pakai RecursiveCharacterTextSplitter
# - prefix "passage: " wajib untuk model multilingual-e5-base
# - metadata payload menyimpan data asli (arab, nama surah, transliterasi, dll)

import json
import os
import sys
import time
import uuid
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    HnswConfigDiff,
    OptimizersConfigDiff,
)
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter

# ─── pengaturan path file dan koneksi ke qdrant ──────────────────
DATASET_PATH = "quran_hybrid_dataset.json"
PROGRESS_PATH = "chunking_progress.json"
QDRANT_URL = "http://localhost:6333"
COLLECTION_NAME = "quran_hybrid_collection"

# jumlah dokumen yang diproses per iterasi, bisa disesuaikan kalau ram terbatas
BATCH_SIZE = 64

# dimensi vektor sesuai spesifikasi model multilingual-e5-base
EMBEDDING_DIM = 768
MODEL_NAME = "intfloat/multilingual-e5-base"

# ─── daftar surah yang harus di-skip karena metadata tidak lengkap ────
EXCLUDED_SURAHS = {7, 17, 26}

# field minimal yang WAJIB ada dan tidak boleh kosong di setiap entry
REQUIRED_FIELDS = [
    "surah", "ayat", "nama_surah", "teks_arab",
    "terjemahan", "tafsir_wajiz", "tafsir_tahlili",
]

# ─── konfigurasi text splitter untuk tafsir_tahlili ──────────────
# chunk_size 1500 karakter optimal untuk tafsir Qur'an:
# - cukup lebar menangkap satu argumen/pembahasan utuh
# - tetap di bawah batas token model embedding (~512 token ≈ 1500-2000 char)
# chunk_overlap 200 supaya konteks antar chunk tidak putus di tengah kalimat
CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200

tafsir_splitter = RecursiveCharacterTextSplitter(
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP,
    separators=["\n\n", "\n", ". ", "، ", ", ", " "],
    length_function=len,
    is_separator_regex=False,
)


# ─── fungsi utilitas ─────────────────────────────────────────────

def load_progress() -> int:
    """Baca file progress untuk tahu berapa dokumen yang sudah masuk qdrant.
    Kalau file belum ada berarti belum pernah jalan sama sekali."""
    if os.path.exists(PROGRESS_PATH):
        with open(PROGRESS_PATH, "r") as f:
            data = json.load(f)
            return data.get("uploaded_count", 0)
    return 0


def save_progress(count: int):
    """Simpan jumlah dokumen yang sudah berhasil di-upload ke file json.
    File ini yang jadi penanda supaya bisa resume kalau terhenti."""
    with open(PROGRESS_PATH, "w") as f:
        json.dump({"uploaded_count": count}, f)


def clear_progress():
    """Hapus file progress kalau semua dokumen sudah selesai diproses.
    Biar bersih dan tidak membingungkan kalau mau jalankan ulang nanti."""
    if os.path.exists(PROGRESS_PATH):
        os.remove(PROGRESS_PATH)


def is_valid_entry(item: dict) -> bool:
    """Cek apakah entry punya semua field minimal yang diperlukan.
    Entry yang tidak lengkap akan di-skip untuk menjaga kualitas embedding."""
    for field in REQUIRED_FIELDS:
        value = item.get(field)
        if value is None:
            return False
        # field string tidak boleh kosong (kecuali angka seperti surah/ayat)
        if isinstance(value, str) and not value.strip():
            return False
    return True


def extract_thematic_keywords(item: dict) -> str:
    """Ekstrak keyword tematik dari metadata untuk memperkaya page_content.
    Keyword ini membantu model menangkap konteks semantik yang lebih luas."""
    parts = []
    nama = item.get("nama_surah", "")
    arti = item.get("arti_surah", "")
    kategori = item.get("kategori_surah", "")
    if nama:
        parts.append(f"Surah {nama}")
    if arti:
        parts.append(f"({arti})")
    if kategori:
        parts.append(f"[{kategori}]")
    return " ".join(parts)


def build_documents(dataset: list[dict]) -> list[dict]:
    """Konversi dataset JSON menjadi list of document-dictionary.
    Setiap entry bisa menghasilkan 1 atau lebih dokumen (kalau tafsir panjang).

    Struktur setiap document:
    - page_content: teks yang akan di-embed (dengan prefix "passage: ")
    - metadata: data asli untuk ditampilkan ke user
    - point_id: UUID deterministik untuk upsert aman
    """
    documents = []
    skipped_surah = 0
    skipped_incomplete = 0

    for item in dataset:
        surah_num = item.get("surah")

        # skip surah yang diketahui bermasalah
        if surah_num in EXCLUDED_SURAHS:
            skipped_surah += 1
            continue

        # skip entry dengan data tidak lengkap
        if not is_valid_entry(item):
            skipped_incomplete += 1
            continue

        # siapkan komponen page_content
        terjemahan = item["terjemahan"].strip()
        keywords = extract_thematic_keywords(item)
        tafsir_tahlili = item.get("tafsir_tahlili", "").strip()
        tafsir_wajiz = item.get("tafsir_wajiz", "").strip()

        # metadata payload — data asli yang tidak di-embed
        metadata = {
            "surah": item["surah"],
            "ayat": item["ayat"],
            "juz": item.get("juz", 0),
            "halaman": item.get("halaman", 0),
            "nama_surah": item.get("nama_surah", ""),
            "arti_surah": item.get("arti_surah", ""),
            "kategori_surah": item.get("kategori_surah", ""),
            "teks_arab": item.get("teks_arab", ""),
            "transliterasi": item.get("transliterasi", ""),
            "terjemahan": terjemahan,
            "catatan_kaki": item.get("catatan_kaki", ""),
            "tafsir_wajiz": tafsir_wajiz,
            "tafsir_tahlili": tafsir_tahlili,
        }

        # ── pecah tafsir_tahlili jika terlalu panjang ────────────
        if len(tafsir_tahlili) > CHUNK_SIZE:
            tafsir_chunks = tafsir_splitter.split_text(tafsir_tahlili)
        else:
            tafsir_chunks = [tafsir_tahlili] if tafsir_tahlili else [""]

        for chunk_idx, tafsir_chunk in enumerate(tafsir_chunks):
            # rakit page_content: terjemahan + keyword + tafsir
            content_parts = [
                f"Terjemahan: {terjemahan}",
                f"Tema: {keywords}",
                f"Tafsir Ringkas: {tafsir_wajiz}",
            ]
            if tafsir_chunk:
                content_parts.append(f"Tafsir Tahlili: {tafsir_chunk}")

            raw_content = "\n".join(content_parts)

            # WAJIB: prefix "passage: " untuk model multilingual-e5-base
            page_content = f"passage: {raw_content}"

            # buat UUID deterministik, sertakan chunk_idx untuk keunikan
            point_id = str(uuid.uuid5(
                uuid.NAMESPACE_DNS,
                f"quran-{item['surah']}-{item['ayat']}-c{chunk_idx}"
            ))

            # tambahkan info chunk ke metadata supaya bisa di-trace
            doc_metadata = {
                **metadata,
                "chunk_index": chunk_idx,
                "total_chunks": len(tafsir_chunks),
            }

            documents.append({
                "page_content": page_content,
                "metadata": doc_metadata,
                "point_id": point_id,
            })

    print(f"  Data cleansing report:")
    print(f"    - Skipped (surah {EXCLUDED_SURAHS}): {skipped_surah} entries")
    print(f"    - Skipped (incomplete data): {skipped_incomplete} entries")
    print(f"    - Total dokumen setelah chunking: {len(documents)}")

    return documents


# ─── pipeline utama ──────────────────────────────────────────────

def main():
    # pastikan dataset hasil ingestion sudah ada sebelum mulai
    if not os.path.exists(DATASET_PATH):
        print(f"Error: Dataset {DATASET_PATH} tidak ditemukan. "
              "Jalankan ingestion.py terlebih dahulu.")
        sys.exit(1)

    print("=" * 60)
    print("CHUNKING PIPELINE v2 — Hybrid Embedding + Metadata")
    print("=" * 60)

    print("\n1. Membaca dataset hybrid MSI Kemenag...")
    with open(DATASET_PATH, "r", encoding="utf-8") as f:
        dataset = json.load(f)

    total_raw = len(dataset)
    print(f"   Total ayat mentah dalam dataset: {total_raw}")

    # ── data cleansing & document building ─────────────────────
    print("\n2. Menjalankan data cleansing & chunking...")
    documents = build_documents(dataset)
    total_docs = len(documents)

    if total_docs == 0:
        print("Error: Tidak ada dokumen valid setelah cleansing.")
        sys.exit(1)

    # ── cek progress resume ────────────────────────────────────
    uploaded_count = load_progress()

    if uploaded_count >= total_docs:
        print("\nSemua dokumen sudah di-upload sebelumnya. Tidak ada yang perlu diproses.")
        clear_progress()
        return

    if uploaded_count > 0:
        print(f"\n   Melanjutkan dari progress sebelumnya: {uploaded_count}/{total_docs} "
              f"sudah ter-upload.")
        print(f"   Sisa: {total_docs - uploaded_count} dokumen.")
    else:
        print("\n   Memulai proses dari awal...")

    # ── muat model embedding ───────────────────────────────────
    print("\n3. Memuat model embedding (multilingual-e5-base) di CPU...")
    embeddings = HuggingFaceEmbeddings(
        model_name=MODEL_NAME,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )
    print("   Model berhasil dimuat.")

    # ── koneksi ke Qdrant ──────────────────────────────────────
    print("\n4. Menghubungkan ke Qdrant...")
    client = QdrantClient(url=QDRANT_URL, timeout=120)

    if uploaded_count == 0:
        print("   Membuat collection baru di Qdrant (force recreate)...")
        if client.collection_exists(COLLECTION_NAME):
            client.delete_collection(COLLECTION_NAME)

        # collection dengan HNSW config yang dioptimalkan untuk recall tinggi
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(
                size=EMBEDDING_DIM,
                distance=Distance.COSINE,
            ),
            hnsw_config=HnswConfigDiff(
                m=32,                   # lebih banyak koneksi = recall lebih tinggi
                ef_construct=200,       # effort saat index building
                full_scan_threshold=10000,
            ),
            optimizers_config=OptimizersConfigDiff(
                indexing_threshold=20000,
            ),
        )
        print("   Collection berhasil dibuat dengan HNSW config optimal.")
    else:
        if not client.collection_exists(COLLECTION_NAME):
            print("   Collection tidak ditemukan. Memulai ulang dari awal...")
            uploaded_count = 0
            save_progress(0)
            client.create_collection(
                collection_name=COLLECTION_NAME,
                vectors_config=VectorParams(
                    size=EMBEDDING_DIM,
                    distance=Distance.COSINE,
                ),
                hnsw_config=HnswConfigDiff(
                    m=32,
                    ef_construct=200,
                    full_scan_threshold=10000,
                ),
                optimizers_config=OptimizersConfigDiff(
                    indexing_threshold=20000,
                ),
            )

    # ── vektorisasi & upload ───────────────────────────────────
    remaining_docs = documents[uploaded_count:]
    total_batches = (len(remaining_docs) + BATCH_SIZE - 1) // BATCH_SIZE

    print(f"\n5. Memulai vektorisasi & upload dalam {total_batches} batch "
          f"(@ {BATCH_SIZE} dokumen)...\n")

    for batch_idx in range(total_batches):
        batch_start = batch_idx * BATCH_SIZE
        batch_end = min(batch_start + BATCH_SIZE, len(remaining_docs))
        batch_docs = remaining_docs[batch_start:batch_end]

        global_start = uploaded_count + batch_start
        global_end = uploaded_count + batch_end

        # info surah range untuk monitoring
        first_meta = batch_docs[0]["metadata"]
        last_meta = batch_docs[-1]["metadata"]
        surah_range = (
            f"Surah {first_meta['nama_surah']}:{first_meta['ayat']}"
            f" – {last_meta['nama_surah']}:{last_meta['ayat']}"
        )

        print(f"  Batch {batch_idx + 1}/{total_batches} "
              f"[{global_start + 1}–{global_end}/{total_docs}] "
              f"({surah_range})")

        try:
            # ambil page_content untuk di-embed
            texts = [doc["page_content"] for doc in batch_docs]

            t0 = time.time()
            vectors = embeddings.embed_documents(texts)
            embed_time = time.time() - t0

            # bangun list of points untuk qdrant
            points = []
            for i, doc in enumerate(batch_docs):
                points.append(PointStruct(
                    id=doc["point_id"],
                    vector=vectors[i],
                    payload={
                        "page_content": doc["page_content"],
                        "metadata": doc["metadata"],
                    },
                ))

            # upsert ke qdrant
            client.upsert(collection_name=COLLECTION_NAME, points=points)

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

    # ── selesai ────────────────────────────────────────────────
    clear_progress()

    info = client.get_collection(COLLECTION_NAME)
    print(f"\n{'=' * 60}")
    print(f"SELESAI! Vector Database berhasil dibangun di Qdrant.")
    print(f"  Total vektor di collection: {info.points_count}")
    print(f"  HNSW config: m=32, ef_construct=200")
    print(f"  Chunk config: size={CHUNK_SIZE}, overlap={CHUNK_OVERLAP}")
    print(f"  File progress ({PROGRESS_PATH}) telah dihapus.")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
