# script ini mengambil data ayat dan tafsir dari api kemenag lalu
# menyimpannya ke file json sebagai dataset untuk proses embedding.
# sudah dilengkapi auto-resume kalau terhenti dan auto-cleansing
# kalau ada data yang tidak lengkap dari eksekusi sebelumnya.

import requests
import json
import time
import re
import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# muat konfigurasi dari file .env yang ada di folder data_pipeline
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)

# endpoint api kemenag untuk data al-quran
BASE_URL = "https://quran-api.lpmqkemenag.id/api-alquran"

# token api harus diisi di file .env, tanpa token tidak bisa lanjut
API_TOKEN = os.getenv("KEMENAG_API_TOKEN")
if not API_TOKEN:
    print("ERROR: KEMENAG_API_TOKEN tidak ditemukan di file .env")
    sys.exit(1) 

# header yang dikirim ke api kemenag di setiap request
HEADERS = {
    "Authorization": API_TOKEN,
    "user": "agusns "
}


def bersihkan_html(teks: str) -> str:
    """Bersihkan tag html dari teks tafsir yang dikembalikan api.
    Kadang field tahlili mengandung tag html yang tidak kita butuhkan."""
    if not teks: return ""
    clean = re.sub(r'<[^>]+>', ' ', str(teks))
    return " ".join(clean.split())


# nama file output yang jadi dataset untuk chunking
FILE_NAME = "quran_hybrid_dataset.json"
dataset_quran = []
start_surah = 1

# bagian ini menangani resume dan pembersihan otomatis.
# kalau file json sudah ada dari eksekusi sebelumnya, kita cek
# apakah datanya utuh atau ada yang bolong di tengah jalan.
if os.path.exists(FILE_NAME):
    try:
        with open(FILE_NAME, "r", encoding="utf-8") as f:
            dataset_quran = json.load(f)
            
            if dataset_quran:
                surah_bermasalah = None
                
                # periksa apakah ada ayat yang tafsirnya kosong.
                # ini pertanda bahwa api sempat gagal tapi tidak terdeteksi.
                for item in dataset_quran:
                    if item["tafsir_wajiz"] == "" and item["tafsir_tahlili"] == "":
                        surah_bermasalah = item["surah"]
                        break
                
                if surah_bermasalah:
                    start_surah = surah_bermasalah
                    print(f"Data tidak utuh terdeteksi mulai Surah {start_surah}. Membersihkan anomali...")
                else:
                    # data sebelumnya utuh, lanjutkan dari surah terakhir
                    start_surah = dataset_quran[-1]["surah"]
                
                # buang semua data dari surah bermasalah ke atas
                # supaya bisa di-download ulang dari awal surah tersebut
                dataset_quran = [item for item in dataset_quran if item["surah"] < start_surah]
                
                if start_surah > 114:
                    print("Data sudah lengkap 114 Surah. Proses dihentikan.")
                    sys.exit(0)
                    
                print(f"Melanjutkan akuisisi dari awal Surah ke-{start_surah}...")
    except json.JSONDecodeError:
        # file json-nya rusak total, lebih aman mulai dari nol
        print("File JSON rusak, memulai proses dari awal...")

# mulai proses pengambilan data dari api kemenag
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

# simpan metadata tiap surah ke dictionary biar gampang diakses pakai nomor surah
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
        # ambil semua ayat untuk surah ini
        res_ayat = requests.get(f"{BASE_URL}/ayat/local/{surah_num}", headers=HEADERS).json()
        
        # kalau kena rate limit, hentikan dan biarkan resume di lain waktu
        if res_ayat.get("code") == 429 or res_ayat.get("res") == "error":
            print(f"PERINGATAN: Limit API harian tercapai saat mengakses Surah {surah_num}.")
            break
            
        data_ayat = res_ayat.get('data', [])
        
        for ayat_data in data_ayat:
            # id global ayat dipakai untuk mengambil tafsir per ayat
            ayat_global_id = ayat_data["id"] 
            tafsir_data = None
            
            # coba ambil tafsir maksimal tiga kali sebelum menyerah.
            # api kemenag kadang lambat atau tidak stabil.
            for _ in range(3): 
                try:
                    res_tafsir = requests.get(
                        f"{BASE_URL}/ayat/local/tafsir/{ayat_global_id}",
                        headers=HEADERS,
                        timeout=10
                    ).json()
                    
                    if res_tafsir.get("code") == 429 or res_tafsir.get("res") == "error":
                        raise Exception("Limit Tercapai")
                    
                    if res_tafsir.get("data"):
                        tafsir_data = res_tafsir["data"][0]
                        break 
                except Exception:
                    # tunggu sebentar sebelum coba lagi
                    time.sleep(1)
            
            # kalau setelah tiga kali tetap gagal, hentikan total.
            # lebih baik berhenti daripada menyimpan data yang bolong.
            if tafsir_data is None:
                raise Exception(
                    f"Gagal mengambil tafsir untuk Surah {surah_num} Ayat {ayat_data['ayat']}. "
                    "Koneksi diputus agar data tidak bolong."
                )
            
            # susun satu record lengkap dari data ayat dan tafsir
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

            # jeda antar ayat supaya tidak membebani server kemenag
            time.sleep(1)
            
        print(f"Surah {surah_num} - Berhasil mengekstrak {len(data_ayat)} ayat penuh.")
        
        # simpan ke file setiap selesai satu surah sebagai checkpoint
        with open(FILE_NAME, "w", encoding="utf-8") as file:
            json.dump(dataset_quran, file, ensure_ascii=False, indent=2)
            
    except Exception as e:
        # kalau terjadi error, data yang sudah terkumpul tetap tersimpan
        # karena kita simpan per surah di atas
        print(f"Proses terhenti pada Surah {surah_num}: {e}")
        break 

print("\nPROSES AKUISISI SELESAI ATAU TERHENTI.")