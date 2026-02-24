quran-rag-system/
│
├── data_pipeline/                # Folder khusus untuk akuisisi dan pra-pemrosesan data
│   ├── raw_data/                 # Menyimpan hasil respons API asli (format .json)
│   ├── processed_data/           # Menyimpan hasil ekstrak dalam bentuk sheet (.csv / .xlsx)
│   ├── ingestion_script.py       # Skrip Python untuk hit API Kemenag iteratif 114 surat
│   ├── chunking_script.py        # Skrip untuk Structural Chunking per ayat
│   └── requirements.txt          # Library Python khusus pipeline (requests, pandas)
│
├── backend/                      # Folder khusus logika RAG dan API Backend (Python)
│   ├── app/
│   │   ├── main.py               # Entry point untuk FastAPI/Flask
│   │   ├── routes/               # Endpoint API yang akan dipanggil oleh Flutter
│   │   ├── rag_engine/           # Logika LangChain, prompt, dan pemanggilan LLM
│   │   └── database/             # Skrip koneksi ke Vector Database (ChromaDB/Qdrant)
│   ├── vector_store/             # (Opsional) Tempat menyimpan file database vektor lokal (jika pakai ChromaDB)
│   ├── evaluation/               # Skrip metrik DeepEval dan BERTScore
│   └── requirements.txt          # Library backend (langchain, fastapi, chromadb, dll)
│
├── frontend/                     # Folder khusus aplikasi Mobile (Flutter/Dart)
│   ├── android/                  
│   ├── ios/                      
│   ├── lib/                      
│   │   ├── main.dart             # Entry point aplikasi Flutter
│   │   ├── screens/              # UI/UX aplikasi (halaman chat, riwayat, dll)
│   │   ├── services/             # Fungsi REST API request ke backend Python
│   │   └── models/               # Model data Dart (mengatur mapping JSON dari backend)
│   └── pubspec.yaml              # Dependensi Flutter
│
└── README.md                     # Dokumentasi utama proyek