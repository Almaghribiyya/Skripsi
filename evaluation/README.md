# Evaluasi Performa Sistem Tanya Jawab Al-Qur'an

Modul evaluasi end-to-end untuk mengukur performa Sistem Tanya Jawab
Al-Qur'an berbasis Retrieval-Augmented Generation (RAG).

## Metrik Evaluasi

| Metrik | Library | Deskripsi |
|--------|---------|-----------|
| Faithfulness | DeepEval | Apakah jawaban benar-benar *grounded* pada konteks retrieval? |
| Answer Relevancy | DeepEval | Apakah jawaban relevan dengan pertanyaan pengguna? |
| BERTScore (P/R/F1) | bert-score | Kemiripan semantik jawaban sistem vs. jawaban referensi |
| Negative Rejection | Custom | Akurasi penolakan pertanyaan yang tidak terkait Al-Qur'an |

## Prasyarat

1. Backend API sudah berjalan (Qdrant + FastAPI)
2. Qdrant sudah terisi data ayat (jalankan data pipeline)
3. Python 3.10+
4. `GEMINI_API_KEY` di environment (untuk evaluasi DeepEval)

## Instalasi

```bash
cd evaluation
pip install -r requirements.txt
```

## Penggunaan

### Evaluasi lengkap (DeepEval + BERTScore + Rejection)

```bash
python run_evaluation.py --api-url http://localhost:8000
```

### Hanya BERTScore + Rejection (tanpa DeepEval)

```bash
python run_evaluation.py --skip-deepeval
```

### Hanya DeepEval + Rejection (tanpa BERTScore)

```bash
python run_evaluation.py --skip-bertscore
```

### Dengan autentikasi Firebase

```bash
python run_evaluation.py --auth-token YOUR_FIREBASE_TOKEN
```

### Menggunakan model evaluator tertentu

```bash
python run_evaluation.py --eval-model gemini/gemini-2.0-flash
```

> **Catatan:** Jika `AUTH_ENABLED=true` di backend, nonaktifkan sementara
> di file `.env` atau gunakan `--auth-token` untuk evaluasi.

## Struktur Output

```
results/
├── hasil_evaluasi_YYYYMMDD_HHMMSS.csv     # semua hasil per kasus uji
├── deepeval_detail_YYYYMMDD_HHMMSS.csv    # skor DeepEval per kasus
├── bertscore_detail_YYYYMMDD_HHMMSS.csv   # skor BERTScore per kasus
└── ringkasan_metrik_YYYYMMDD_HHMMSS.csv   # rata-rata semua metrik
```

## Dataset Evaluasi

File `eval_dataset.json` berisi **25 kasus uji** gold standard:
- **20 pertanyaan positif** (harus dijawab) dari 5 kategori
- **5 pertanyaan negatif** (harus ditolak) — topik non-Al-Qur'an

| Kategori | Jumlah | Deskripsi |
|----------|--------|-----------|
| Akidah | 5 | Keyakinan dan keimanan |
| Ibadah | 5 | Ibadah dan perintah Allah |
| Akhlak | 4 | Akhlak dan budi pekerti |
| Kisah | 3 | Kisah-kisah dalam Al-Qur'an |
| Hukum | 3 | Hukum dan muamalah |
| Penolakan | 5 | Pertanyaan non-Al-Qur'an |

## Interpretasi Hasil

| Metrik | Rentang | Target Minimum |
|--------|---------|----------------|
| Faithfulness | 0.0 — 1.0 | ≥ 0.70 |
| Answer Relevancy | 0.0 — 1.0 | ≥ 0.70 |
| BERTScore F1 | −1.0 — 1.0 | ≥ 0.50 |
| Negative Rejection | 0% — 100% | 100% |

### Penjelasan Metrik

- **Faithfulness** mengukur apakah setiap klaim dalam jawaban LLM
  didukung oleh konteks referensi (ayat Al-Qur'an). Skor tinggi
  menunjukkan bahwa jawaban benar-benar *grounded* dan minim halusinasi.

- **Answer Relevancy** mengukur apakah jawaban menjawab pertanyaan
  pengguna secara langsung dan relevan.

- **BERTScore** mengukur kemiripan semantik antara jawaban sistem
  dengan jawaban referensi (gold standard) menggunakan embedding
  dari model bahasa pra-latih.

- **Negative Rejection Rate** mengukur persentase pertanyaan
  non-Al-Qur'an yang berhasil ditolak sistem. Target ideal adalah 100%.

## Menambah Kasus Uji

Untuk menambah kasus uji, edit `eval_dataset.json`:

```json
{
  "id": 26,
  "kategori": "akidah",
  "topik": "Surga dan Neraka",
  "pertanyaan": "Bagaimana Al-Qur'an menggambarkan surga?",
  "jawaban_referensi": "Al-Qur'an menggambarkan surga sebagai ...",
  "should_answer": true
}
```

Untuk kasus penolakan, kosongkan `jawaban_referensi` dan set
`should_answer` ke `false`.
