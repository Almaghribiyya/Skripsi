import requests
import json
import time
import re
import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# Memuat variabel dari data_pipeline/.env
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)

BASE_URL = "https://quran-api.lpmqkemenag.id/api-alquran"
API_TOKEN = os.getenv("KEMENAG_API_TOKEN")
if not API_TOKEN:
    print("ERROR: KEMENAG_API_TOKEN tidak ditemukan di file .env")
    sys.exit(1) 
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

# AUTO-CLEANSING & RESUME
if os.path.exists(FILE_NAME):
    try:
        with open(FILE_NAME, "r", encoding="utf-8") as f:
            dataset_quran = json.load(f)
            
            if dataset_quran:
                surah_bermasalah = None
                
                # Mendeteksi surah pertama yang mengalami Silent Failure (data kosong)
                for item in dataset_quran:
                    if item["tafsir_wajiz"] == "" and item["tafsir_tahlili"] == "":
                        surah_bermasalah = item["surah"]
                        break
                
                if surah_bermasalah:
                    start_surah = surah_bermasalah
                    print(f"Data tidak utuh terdeteksi mulai Surah {start_surah}. Membersihkan anomali...")
                else:
                    start_surah = dataset_quran[-1]["surah"]
                
                # Menghapus keseluruhan surah yang bermasalah beserta surah setelahnya
                dataset_quran = [item for item in dataset_quran if item["surah"] < start_surah]
                
                if start_surah > 114:
                    print("Data sudah lengkap 114 Surah. Proses dihentikan.")
                    sys.exit(0)
                    
                print(f"Melanjutkan akuisisi dari awal Surah ke-{start_surah}...")
    except json.JSONDecodeError:
        print("File JSON rusak, memulai proses dari awal...")

# PROSES AKUISISI DATA
print("1. Mengambil metadata 114 Surah...")
try:
    res_surah = requests.get(f"{BASE_URL}/surah/local/1/114", headers=HEADERS).json()
except Exception as e:
    print(f"ERROR: Gagal menghubungi server Kemenag. Detail: {e}")
    sys.exit(1)

data_surah_list = res_surah.get('data', [])
if not data_surah_list:
    print("ERROR: Gagal mendapatkan daftar Surah. Token kedaluwarsa atau limit habis.")
    sys.exit(1)

surah_metadata = {
    s['id']: {
        "nama_surah": s['nama'],
        "arti_surah": s['arti'],
        "kategori": s['kategori'],
        "jumlah_ayat": s['jmlAyat']
    } for s in data_surah_list
} 

print("2. Memulai proses akuisisi Ayat dan Tafsir secara utuh...")

for surah_num in range(start_surah, 115):
    try:
        res_ayat = requests.get(f"{BASE_URL}/ayat/local/{surah_num}", headers=HEADERS).json()
        
        if res_ayat.get("code") == 429 or res_ayat.get("res") == "error":
            print(f"PERINGATAN: Limit API harian tercapai saat mengakses Surah {surah_num}.")
            break
            
        data_ayat = res_ayat.get('data', [])
        
        for ayat_data in data_ayat:
            ayat_global_id = ayat_data["id"] 
            tafsir_data = None
            
            for _ in range(3): 
                try:
                    res_tafsir = requests.get(f"{BASE_URL}/ayat/local/tafsir/{ayat_global_id}", headers=HEADERS, timeout=10).json()
                    
                    if res_tafsir.get("code") == 429 or res_tafsir.get("res") == "error":
                        raise Exception("Limit Tercapai")
                    
                    if res_tafsir.get("data"):
                        tafsir_data = res_tafsir["data"][0]
                        break 
                except Exception:
                    time.sleep(1)
            
            # Cegah Silent Failure. Jika 3 kali gagal, hentikan program!
            if tafsir_data is None:
                raise Exception(f"Gagal mengambil tafsir untuk Surah {surah_num} Ayat {ayat_data['ayat']}. Koneksi diputus agar data tidak bolong.")
            
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
            time.sleep(1) # Atau bahkan time.sleep(1) untuk surah-surah panjang
            
        print(f"Surah {surah_num} - Berhasil mengekstrak {len(data_ayat)} ayat penuh.")
        
        with open(FILE_NAME, "w", encoding="utf-8") as file:
            json.dump(dataset_quran, file, ensure_ascii=False, indent=2)
            
    except Exception as e:
        print(f"Proses terhenti pada Surah {surah_num}: {e}")
        break 

print("\nPROSES AKUISISI SELESAI ATAU TERHENTI.")