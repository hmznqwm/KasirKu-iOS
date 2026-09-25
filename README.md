# KasirKu Mobile (Flutter / Dart) — Versi OFFLINE

Versi Android dari aplikasi **KasirKu**, sekarang berjalan **100% offline**.
Tidak ada lagi backend PHP/MySQL/hosting sama sekali — semua data (produk,
user, transaksi, panduan obat) disimpan langsung di storage HP memakai
database SQLite lokal (`sqflite`).

File-file lama (`api.php`, `config.php`, `db.php`, `helpers.php`,
`db_kasirku.sql`) **tidak dipakai lagi** oleh aplikasi ini. Semua logikanya
sudah dipindahkan (di-port 1:1) ke dalam Dart:

| Dulu (PHP/MySQL online)      | Sekarang (Dart/SQLite offline)          |
|-------------------------------|------------------------------------------|
| `config.php`, `db.php`        | `lib/services/db_helper.dart`             |
| `helpers.php`                 | `lib/services/local_helpers.dart`         |
| `api.php` (semua `action`)    | `lib/services/api_service.dart`           |
| Tabel MySQL (`db_kasirku.sql`)| Tabel SQLite yang sama, dibuat otomatis   |
| Token sesi 6 jam di tabel `tokens` | Sesi login disimpan di HP (SharedPreferences), tidak kedaluwarsa |
| "Atur alamat server" saat pertama buka | **Dihapus** — langsung ke halaman Login |

Seluruh layar (`lib/screens/*`) **tidak diubah logikanya** — mereka tetap
memanggil `ApiService.instance.call('produk.list', ...)` dsb. seperti
sebelumnya. Yang berubah hanya isi `ApiService`: dulu mengirim HTTP request
ke internet, sekarang langsung baca/tulis ke database SQLite di HP.

## Fitur (tetap 1:1, tapi offline)

- Login & sesi tersimpan di HP (`auth.login`, `me`)
- Dashboard ringkasan penjualan, profit, & stok kritis
- Manajemen Produk (khusus ADMIN: tambah/edit/hapus/hapus massal/import massal via template CSV)
- Kasir (POS) — keranjang, diskon, metode bayar, checkout, struk transaksi
- Riwayat Transaksi — cari & hapus (khusus ADMIN, stok otomatis dikembalikan)
- Manajemen User khusus ADMIN
- Panduan Obat berbasis gejala (data gejala & obat sudah ikut ter-seed)

## Login Pertama Kali

Saat aplikasi pertama kali dibuka, database lokal otomatis dibuat dan
diisi dengan 1 akun admin bawaan:

```
Email    : admin@pos.local
Password : admin123
```

**Segera login lalu ganti password / buat akun kasir baru** lewat menu
**Lainnya → Manajemen User** (khusus ADMIN). Data produk masih kosong,
tambahkan lewat menu **Produk**.

## Struktur Folder

```
kasirku_mobile/
 ├─ pubspec.yaml
 ├─ analysis_options.yaml
 ├─ lib/
 │   ├─ main.dart
 │   ├─ models/models.dart
 │   ├─ services/db_helper.dart          # skema & seed database SQLite lokal
 │   ├─ services/local_helpers.dart      # util (hash, format tanggal, dll)
 │   ├─ services/api_service.dart        # "otak" aplikasi, semua logika offline
 │   ├─ services/auth_provider.dart      # status login & sesi
 │   ├─ theme/app_theme.dart
 │   ├─ utils/formatters.dart
 │   ├─ widgets/common.dart
 │   └─ screens/                         # semua halaman UI (tidak berubah)
 └─ (folder android/ dibuat otomatis di langkah 2 di bawah)
```

## Cara Menjalankan (Android)

Folder platform `android/` belum termasuk di paket ini supaya versi
Gradle/Kotlin-nya selalu cocok dengan Flutter SDK yang Anda pasang. Ikuti
langkah berikut (sekali saja):

1. **Install Flutter SDK** (jika belum): https://docs.flutter.dev/get-started/install
   lalu jalankan `flutter doctor` sampai Android toolchain ✅.

2. Masuk ke folder project ini, lalu buat platform Android:
   ```bash
   cd kasirku_mobile
   flutter create --platforms=android --org com.kasirku .
   ```
   Perintah ini **tidak akan menimpa** `lib/` dan `pubspec.yaml` yang sudah
   ada — ia hanya menambahkan folder `android/` yang hilang.

3. **Tidak perlu** menambahkan izin internet — aplikasi ini murni offline
   dan tidak melakukan panggilan jaringan apa pun.

4. Ambil dependency:
   ```bash
   flutter pub get
   ```

5. Jalankan ke HP/emulator:
   ```bash
   flutter run
   ```
   Atau build APK rilis:
   ```bash
   flutter build apk --release
   ```
   Hasil APK ada di `build/app/outputs/flutter-apk/app-release.apk`.

## Di Mana Data Disimpan?

Database SQLite (`kasirku_offline.db`) disimpan di folder data internal
aplikasi Android (mis. `/data/data/com.kasirku.kasirku_mobile/databases/`).
Data ini:

- **Aman & privat** — hanya bisa diakses oleh aplikasi ini sendiri.
- **Tetap ada** walau HP mati/restart, dan walau tidak ada koneksi internet
  sama sekali.
- **Akan terhapus** jika aplikasi di-uninstall, atau jika penyimpanan
  aplikasi (storage) dibersihkan lewat menu *Pengaturan Android → Apps →
  Storage → Clear Data*. Jika ingin fitur backup/ekspor data ke file,
  ini bisa ditambahkan sebagai pengembangan berikutnya.

## Catatan Penting

- File `api.php`, `config.php`, `db.php`, `helpers.php`, dan
  `db_kasirku.sql` (backend PHP + MySQL yang lama) **sudah tidak
  diperlukan** untuk aplikasi mobile ini dan boleh diabaikan/dihapus dari
  proyek mobile. Simpan saja bila masih dipakai versi web terpisah.
- Karena datanya lokal per-HP, kasir yang login di HP A dan HP B akan
  **punya data masing-masing yang terpisah** (tidak sinkron otomatis
  antar perangkat) — sesuai permintaan "kasir offline, data tersimpan di
  storage".
- Role **ADMIN** bisa mengelola Produk, User, dan menghapus Transaksi.
  Role **KASIR** hanya bisa berjualan (Kasir), melihat Produk/Riwayat, dan
  memakai Panduan Obat.
