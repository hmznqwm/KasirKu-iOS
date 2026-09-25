import os
import requests
import urllib.parse
from io import BytesIO
from PIL import Image
import time
from dotenv import load_dotenv
from supabase import create_client, Client

# 1. Muat rahasia dari file .env
load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

# 2. Inisialisasi Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Buat folder lokal
FOLDER_OUTPUT = "hasil_foto_menu"
os.makedirs(FOLDER_OUTPUT, exist_ok=True)

def generate_and_upload_image(product):
    nama_menu = product['nama']
    kategori = product['kategori']
    kode = product['kode']
    lokasi_file_lokal = f"{FOLDER_OUTPUT}/{kode}.jpg"
    
    # Lewati jika gambar sudah ada
    if os.path.exists(lokasi_file_lokal):
        print(f"[SKIP] {kode} - {nama_menu} (Sudah ada)", flush=True)
        return
        
    print(f"[+] Memulai: {kode} - {nama_menu}...", flush=True)
    
    try:
        prompt_teks = f"A professional, aesthetic, and appetizing food photography of an Indonesian cafe menu named '{nama_menu}'. It is a {kategori}. Photorealistic, top-down view, clean bright cafe table background, highly detailed, 4k."
        
        url_prompt = urllib.parse.quote(prompt_teks)
        # Menggunakan model turbo agar sangat cepat dan tidak kena rate limit
        image_url = f"https://image.pollinations.ai/prompt/{url_prompt}?width=800&height=800&nologo=true&model=flux&seed={hash(kode)}"
        
        # Download gambar dengan retry logic (lebih sabar)
        for attempt in range(15):
            try:
                img_response = requests.get(image_url, timeout=45)
                
                if img_response.status_code == 200:
                    img = Image.open(BytesIO(img_response.content))
                    img = img.convert('RGB')
                    
                    # Crop 50px bagian bawah (Watermark)
                    width, height = img.size
                    img = img.crop((0, 0, width, height - 50))
                    
                    # Simpan dengan kompresi kualitas
                    img.save(lokasi_file_lokal, "JPEG", optimize=True, quality=80)
                    
                    ukuran_kb = os.path.getsize(lokasi_file_lokal) / 1024
                    print(f"[OK] Selesai: {kode} ({ukuran_kb:.1f} KB)", flush=True)
                    return # Berhasil, keluar dari fungsi
                elif img_response.status_code == 429:
                    wait_time = 15 + (attempt * 10) # 15s, 25s, 35s, dst.
                    print(f"[ANTRE] {kode} - Server sibuk, menunggu {wait_time} detik...", flush=True)
                    time.sleep(wait_time)
                else:
                    print(f"[GAGAL] {kode} - Server Error {img_response.status_code}, coba lagi...", flush=True)
                    time.sleep(5)
            except requests.exceptions.ReadTimeout:
                print(f"[TIMEOUT] {kode} - Waktu habis, mengulang...", flush=True)
                time.sleep(10)
                
    except Exception as e:
        print(f"[ERROR] {kode} - {nama_menu}: {e}", flush=True)

# ==================== MAIN SCRIPT ====================
print("Mulai mengambil data dari Supabase...", flush=True)
response = supabase.table("produk").select("*").eq("foto", "").execute()
produk_list = response.data

if not produk_list:
    print("Semua produk sudah memiliki foto!", flush=True)
else:
    print(f"Menemukan {len(produk_list)} produk. Memulai Pembuatan Cepat (Turbo Model)...", flush=True)
    
    for produk in produk_list:
        generate_and_upload_image(produk)
        time.sleep(3) # Jeda 3 detik agar server AI tidak mengira kita melakukan serangan SPAM
        
        
    print("\nSELESAI! Seluruh gambar telah diproses.", flush=True)
