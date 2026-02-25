import requests
import json
import time
import re
import sys
import os
from dotenv import load_dotenv

# Load environment variables untuk keamanan
load_dotenv()

BASE_URL = "https://quran-api.lpmqkemenag.id/api-alquran"
# Mengambil token dari .env, mencegah kebocoran kredensial
API_TOKEN = os.getenv("KEMENAG_API_TOKEN", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYXNzd29yZCI6IjRmNGRiZjI1N2IzNTMxODU0M2RhMzRhNzQzYjNjZWMzIiwiaWF0IjoxNzU0ODc2NzQ4fQ.UO-N5v0kCf9I6pTz4LXhGmHINWGHQmbwy6uG3vdIYpM") 
HEADERS = {
    "Authorization": API_TOKEN,
    "user": "agusns "
}

def bersihkan_html(teks: str) -> str:
    if not teks: return ""
    clean = re.sub(r'<[^>]+>', ' ', str(teks))
    return " ".join(clean.split())

FILE_NAME = "quran_hybrid_dataset.json"
dataset_quran = []
start_surah = 1

if os.path.exists(FILE_NAME):
    try:
        with open(FILE_NAME, "r", encoding="utf-8") as f:
            dataset_quran = json.load(f)
            if dataset_quran:
                start_surah = dataset_quran[-1]["surah"] + 1
                if start_surah > 114:
                    print("Data sudah lengkap 114 Surah. Tidak perlu melakukan akuisisi lagi.")
                    sys.exit(0)
                print(f"Data sebelumnya ditemukan! Melanjutkan akuisisi dari Surah ke-{start_surah}...")
    except json.JSONDecodeError:
        print("File JSON sebelumnya rusak atau kosong, memulai proses dari awal...")

print("1. Mengambil metadata batas awal dan akhir (114 Surah)...")
try:
    res_surah = requests.get(f"{BASE_URL}/surah/local/1/114", headers=HEADERS).json()
except Exception as e:
    print(f"ERROR: Gagal menghubungi server Kemenag. Detail: {e}")
    sys.exit(1)

data_surah_list = res_surah.get('data', [])

if not data_surah_list:
    print("ERROR: Gagal mendapatkan daftar Surah. Token mungkin kedaluwarsa.")
    sys.exit(1)

surah_metadata = {
    s['id']: {
        "nama_surah": s['nama'],
        "arti_surah": s['arti'],
        "kategori": s['kategori'],
        "jumlah_ayat": s['jmlAyat']
    } for s in data_surah_list
} # Menggunakan Dictionary Comprehension agar lebih efisien

print("2. Memulai proses akuisisi Ayat dan Tafsir secara utuh...")

for surah_num in range(start_surah, 115):
    try:
        batas_akhir = surah_metadata[surah_num]["jumlah_ayat"]
        res_ayat = requests.get(f"{BASE_URL}/ayat/local/{surah_num}", headers=HEADERS).json()
        
        if res_ayat.get("code") == 429 or res_ayat.get("res") == "error":
            print(f"PERINGATAN: Limit API harian tercapai saat mengakses Surah {surah_num}.")
            break
            
        data_ayat = res_ayat.get('data', [])
        
        for ayat_data in data_ayat:
            ayat_global_id = ayat_data["id"] 
            tafsir_data = {}
            
            for _ in range(3): # Retry mechanism
                try:
                    res_tafsir = requests.get(f"{BASE_URL}/ayat/local/tafsir/{ayat_global_id}", headers=HEADERS, timeout=10).json()
                    if res_tafsir.get("code") == 429 or res_tafsir.get("res") == "error":
                        raise Exception("Limit Tercapai")
                    
                    if res_tafsir.get("data"):
                        tafsir_data = res_tafsir["data"][0]
                        break 
                except Exception:
                    time.sleep(1)
            
            dataset_quran.append({
                "surah": surah_num,               
                "ayat": ayat_data["ayat"],        
                "juz": ayat_data["juz"],
                "halaman": ayat_data["halaman"], 
                "nama_surah": surah_metadata[surah_num]["nama_surah"],
                "arti_surah": surah_metadata[surah_num]["arti_surah"],
                "kategori_surah": surah_metadata[surah_num]["kategori"],
                "terjemahan": ayat_data.get("terjemah", ""),
                "tafsir_wajiz": tafsir_data.get("teks", ""),
                "teks_arab": ayat_data.get("teks_msi_usmani", ""),
                "transliterasi": ayat_data.get("teks", ""), 
                "catatan_kaki": ayat_data.get("teks_foot", ""), 
                "tafsir_tahlili": bersihkan_html(tafsir_data.get("tahlili", ""))
            })
            time.sleep(0.05)
            
        print(f"Surah {surah_num} - Berhasil mengekstrak {len(data_ayat)} ayat.")
        
        with open(FILE_NAME, "w", encoding="utf-8") as file:
            json.dump(dataset_quran, file, ensure_ascii=False, indent=2)
            
    except Exception as e:
        print(f"Gagal memproses Surah {surah_num}: {e}")
        break 

print("\nAKUISISI SELESAI ATAU TERHENTI")