import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
bucket_name = "produk"

import requests

print("Memeriksa Storage Bucket...")
# Pastikan bucket ada dan bersifat publik
buckets = supabase.storage.list_buckets()
if not any(b.name == bucket_name for b in buckets):
    print(f"Bucket '{bucket_name}' belum ada. Membuat bucket baru...")
    headers = {"Authorization": f"Bearer {SUPABASE_KEY}", "Content-Type": "application/json"}
    requests.post(f"{SUPABASE_URL}/storage/v1/bucket", json={"id": bucket_name, "name": bucket_name, "public": True}, headers=headers)
else:
    print(f"Bucket '{bucket_name}' sudah ada.")

folder_lokal = "hasil_foto_menu"
file_fotonya = [f for f in os.listdir(folder_lokal) if f.endswith(".jpg")]

print(f"\nMenemukan {len(file_fotonya)} foto yang siap di-upload ke Supabase.")

for file_nama in file_fotonya:
    lokasi_file = os.path.join(folder_lokal, file_nama)
    kode_produk = file_nama.replace(".jpg", "")
    file_path_di_supabase = f"foto_menu/{file_nama}"
    
    print(f"-> Meng-upload {file_nama}...")
    try:
        # Upload ke storage
        with open(lokasi_file, 'rb') as f:
            # Gunakan upsert=True agar me-replace jika file sudah ada
            supabase.storage.from_(bucket_name).upload(
                path=file_path_di_supabase, 
                file=f, 
                file_options={"content-type": "image/jpeg", "upsert": "true"}
            )
            
        # Dapatkan URL publik
        public_url = supabase.storage.from_(bucket_name).get_public_url(file_path_di_supabase)
        
        # Update database
        supabase.table("produk").update({"foto": public_url}).eq("kode", kode_produk).execute()
        
        print(f"   [OK] {kode_produk} berhasil di-upload dan database diperbarui!")
    except Exception as e:
        print(f"   [GAGAL] {kode_produk}: {e}")

print("\nSELESAI! Semua foto telah tersambung ke Supabase.")
