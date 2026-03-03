# modul ini bertugas mengubah data mentah dari JSON dataset
# menjadi dokumen-dokumen siap embedding untuk Qdrant.
# pemecahan tafsir panjang, data cleansing, dan pembangunan
# page_content hybrid dilakukan di sini.

import uuid

from langchain_text_splitters import RecursiveCharacterTextSplitter

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

_tafsir_splitter = RecursiveCharacterTextSplitter(
    chunk_size=CHUNK_SIZE,
    chunk_overlap=CHUNK_OVERLAP,
    separators=["\n\n", "\n", ". ", "، ", ", ", " "],
    length_function=len,
    is_separator_regex=False,
)


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
            tafsir_chunks = _tafsir_splitter.split_text(tafsir_tahlili)
        else:
            tafsir_chunks = [tafsir_tahlili] if tafsir_tahlili else [""]

        for chunk_idx, tafsir_chunk in enumerate(tafsir_chunks):
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

            # UUID deterministik, sertakan chunk_idx untuk keunikan
            point_id = str(uuid.uuid5(
                uuid.NAMESPACE_DNS,
                f"quran-{item['surah']}-{item['ayat']}-c{chunk_idx}"
            ))

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
