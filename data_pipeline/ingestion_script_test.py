import requests
import json
import time
import re
import sys

# Konfigurasi API
BASE_URL = "https://quran-api.lpmqkemenag.id/api-alquran"
HEADERS = {
    # ⚠️ GANTI DENGAN TOKEN TERBARU JIKA MENGALAMI ERROR TOKEN ⚠️
    "Authorization": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwYXNzd29yZCI6IjRmNGRiZjI1N2IzNTMxODU0M2RhMzRhNzQzYjNjZWMzIiwiaWF0IjoxNzU0ODc2NzQ4fQ.UO-N5v0kCf9I6pTz4LXhGmHINWGHQmbwy6uG3vdIYpM",
    "user": "agusns "
}

# Fungsi untuk membersihkan tag HTML pada Tafsir Tahlili
def bersihkan_html(teks):
    if not teks: return ""
    clean = re.sub(r'<[^>]+>', ' ', str(teks))
    return " ".join(clean.split())

dataset_quran = []
# Menggunakan nama file khusus testing agar tidak merusak file utama
FILE_NAME = "quran_test_dataset.json" 

print("1. Mengambil metadata Surah (Hanya untuk Uji Coba: Surah 1 dan 2)...")
try:
    # Hanya mengambil data surah 1 sampai 2 untuk menghemat kuota API
    res_surah = requests.get(f"{BASE_URL}/surah/local/1/2", headers=HEADERS).json()
except Exception:
    print("❌ ERROR: Gagal menghubungi server Kemenag. Periksa koneksi internet Anda.")
    sys.exit()

data_surah_list = res_surah.get('data', [])

if not data_surah_list:
    print("❌ ERROR: Gagal mendapatkan daftar Surah.")
    print("💡 PENYEBAB: Token API Anda telah KEDALUWARSA atau LIMIT HARIAN telah tercapai.")
    sys.exit()

surah_metadata = {}
for s in data_surah_list:
    surah_metadata[s['id']] = {
        "nama_surah": s['nama'],
        "arti_surah": s['arti'],
        "kategori": s['kategori'],
        "jumlah_ayat": s['jmlAyat']
    }

print("\n2. Memulai proses UJI COBA akuisisi Ayat dan Tafsir (Al-Fatihah & Al-Baqarah)...")
limit_tercapai = False

# Looping dibatasi HANYA untuk surah 1 (Al-Fatihah) dan 2 (Al-Baqarah)
for surah_num in [1, 2]:
    if limit_tercapai:
        break
        
    try:
        batas_akhir = surah_metadata[surah_num]["jumlah_ayat"]
        
        # Menarik ayat berdasarkan ID surah
        res_ayat_req = requests.get(f"{BASE_URL}/ayat/local/{surah_num}", headers=HEADERS)
        res_ayat = res_ayat_req.json()
        
        if res_ayat.get("code") == 429 or res_ayat.get("res") == "error":
            print(f"❌ PERINGATAN: Limit API harian tercapai saat mencoba mengakses Surah {surah_num}.")
            limit_tercapai = True
            break
            
        data_ayat = res_ayat.get('data', [])
        
        print(f"-> Memproses Surah {surah_num}: {surah_metadata[surah_num]['nama_surah']} ({batas_akhir} Ayat)...")
        
        if len(data_ayat) != batas_akhir:
            print(f"   ⚠️ Peringatan: Data tidak utuh! Seharusnya {batas_akhir} ayat, tapi hanya ditarik {len(data_ayat)}.")
        
        for ayat_data in data_ayat:
            ayat_global_id = ayat_data["id"] 
            
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
                    time.sleep(1)
            
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
            
            time.sleep(0.05) # Jeda keamanan
            
        print(f"✅ Surah {surah_num} ({surah_metadata[surah_num]['nama_surah']}) - Berhasil mengekstrak {len(data_ayat)} ayat penuh.")
        
        # Simpan ke file test
        with open(FILE_NAME, "w", encoding="utf-8") as file:
            json.dump(dataset_quran, file, ensure_ascii=False, indent=2)
            
    except Exception as e:
        print(f"❌ Gagal memproses Surah {surah_num} (Koneksi Terputus / Error): {e}")
        break 

if limit_tercapai:
    print("\n⚠️ PROSES TERHENTI KARENA LIMIT HARIAN TERCAPAI ⚠️")
else:
    print(f"\n🎉 UJI COBA SELESAI! Silakan buka file '{FILE_NAME}' untuk memeriksa apakah metadata dan jumlah ayatnya sudah lengkap (total 293 ayat).")