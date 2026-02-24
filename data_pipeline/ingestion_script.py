import requests
import json
import time
import re
import sys
import os

# Konfigurasi API
BASE_URL = "https://quran-api.lpmqkemenag.id/api-alquran"
HEADERS = {
    "Authorization": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYXNzd29yZCI6Ijk3NGM2YjgxZmRiMzNlZjlkNjFjNmY0MWY1YzY5MGI2IiwiaWF0IjoxNzcxODU3NTA0fQ.Gf2Ah0xVV10UaRmjhSFgGKUy7o5KSFRJV9g-LjBuhqY",
    "user": "Almaghribiyya"
}

# Fungsi untuk membersihkan tag HTML pada Tafsir Tahlili
def bersihkan_html(teks):
    if not teks: return ""
    clean = re.sub(r'<[^>]+>', ' ', str(teks))
    return " ".join(clean.split())

dataset_quran = []
FILE_NAME = "quran_hybrid_dataset.json"


# FITUR RESUME: Melanjutkan dari surah terakhir jika sebelumnya terkena limit
start_surah = 1
if os.path.exists(FILE_NAME):
    try:
        with open(FILE_NAME, "r", encoding="utf-8") as f:
            dataset_quran = json.load(f)
            if dataset_quran:
                # Cari surah terakhir yang sudah berhasil disimpan
                last_surah = dataset_quran[-1]["surah"]
                start_surah = last_surah + 1
                if start_surah > 114:
                    print("Data sudah lengkap 114 Surah. Tidak perlu melakukan akuisisi lagi.")
                    sys.exit()
                print(f"Data sebelumnya ditemukan! Melanjutkan akuisisi mulai dari Surah ke-{start_surah}...")
    except json.JSONDecodeError:
        print("File JSON sebelumnya rusak atau kosong, memulai proses dari awal...")

# PROSES AKUISISI DATA
print("1. Mengambil metadata batas awal dan akhir (114 Surah)...")
try:
    res_surah = requests.get(f"{BASE_URL}/surah/local/1/114", headers=HEADERS).json()
except Exception:
    print("ERROR: Gagal menghubungi server Kemenag. Periksa koneksi internet Anda.")
    sys.exit()

data_surah_list = res_surah.get('data', [])

# Sistem Pendeteksi Token Kedaluwarsa / Limit Harian di awal
if not data_surah_list:
    print("ERROR: Gagal mendapatkan daftar Surah.")
    print("PENYEBAB: Token API Anda telah KEDALUWARSA atau LIMIT HARIAN telah tercapai.")
    print("TINDAKAN: Silakan coba lagi besok hari, atau perbarui token Anda melalui Postman.")
    sys.exit()

# Menyimpan metadata batas akhir (jumlah ayat) untuk tiap surah
surah_metadata = {}
for s in data_surah_list:
    surah_metadata[s['id']] = {
        "nama_surah": s['nama'],
        "arti_surah": s['arti'],
        "kategori": s['kategori'],
        "jumlah_ayat": s['jmlAyat']
    }

print("2. Memulai proses akuisisi Ayat dan Tafsir secara utuh...")
limit_tercapai = False

for surah_num in range(start_surah, 115):
    if limit_tercapai:
        break
        
    try:
        batas_akhir = surah_metadata[surah_num]["jumlah_ayat"]
        
        # Menarik ayat berdasarkan ID surah
        res_ayat_req = requests.get(f"{BASE_URL}/ayat/local/{surah_num}", headers=HEADERS)
        res_ayat = res_ayat_req.json()
        
        # Deteksi jika API memblokir request karena limit
        if res_ayat.get("code") == 429 or res_ayat.get("res") == "error":
            print(f"PERINGATAN: Limit API harian tercapai saat mencoba mengakses Surah {surah_num}.")
            limit_tercapai = True
            break
            
        data_ayat = res_ayat.get('data', [])
        
        # Validasi batas akhir ayat
        if len(data_ayat) != batas_akhir:
            print(f"Peringatan: Surah {surah_num} seharusnya memiliki {batas_akhir} ayat, tetapi hanya ditarik {len(data_ayat)}.")
        
        for ayat_data in data_ayat:
            ayat_global_id = ayat_data["id"] 
            
            # Anti-Gagal: Coba hingga 3 kali untuk menarik tafsir
            tafsir_data = {}
            for percobaan in range(3):
                try:
                    res_tafsir_req = requests.get(f"{BASE_URL}/ayat/local/tafsir/{ayat_global_id}", headers=HEADERS, timeout=10)
                    res_tafsir = res_tafsir_req.json()
                    
                    if res_tafsir.get("code") == 429 or res_tafsir.get("res") == "error":
                        raise Exception("Limit Tercapai")
                        
                    if "data" in res_tafsir and len(res_tafsir["data"]) > 0:
                        tafsir_data = res_tafsir["data"][0]
                        break 
                except Exception:
                    time.sleep(1) # Tunggu 1 detik jika koneksi bermasalah
            
            # Membersihkan tafsir tahlili dari tag HTML
            tahlili_bersih = bersihkan_html(tafsir_data.get("tahlili", ""))
            
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
                "tafsir_tahlili": tahlili_bersih
            })
            
            # Jeda agar server Kemenag tidak memblokir koneksi (DDoS protection)
            time.sleep(0.05)
            
        print(f"Surah {surah_num} ({surah_metadata[surah_num]['nama_surah']}) - Berhasil mengekstrak {len(data_ayat)} ayat penuh.")
        
        # FITUR AUTO-SAVE: Simpan data langsung ke file setiap kali 1 surah selesai!
        with open(FILE_NAME, "w", encoding="utf-8") as file:
            json.dump(dataset_quran, file, ensure_ascii=False, indent=2)
            
    except Exception as e:
        print(f"Gagal memproses Surah {surah_num} (Koneksi Terputus / Error): {e}")
        break # Berhenti memproses surah berikutnya agar file JSON tidak rusak

if limit_tercapai:
    print("\nPROSES TERHENTI KARENA LIMIT HARIAN TERCAPAI")
else:
    print("\nAKUISISI SELESAI")