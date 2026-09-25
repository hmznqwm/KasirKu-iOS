import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database lokal (SQLite) yang tersimpan di storage HP.
/// Menggantikan MySQL online (InfinityFree) sepenuhnya - semua data
/// (produk, user, transaksi, dst) sekarang hidup di file
/// `kasirku_offline.db` di dalam penyimpanan aplikasi, bukan lagi di
/// hosting/internet. Struktur tabel dibuat identik dengan db_kasirku.sql
/// supaya semua logika di ApiService bisa 1:1 mengikuti versi PHP-nya.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String defaultAdminEmail = 'admin@pos.local';
  static const String defaultAdminPassword = 'admin123';

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'kasirku_offline.db');
    final db = await openDatabase(
      path,
      version: 15,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await mergeHotIceProducts(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'KASIR',
        status TEXT NOT NULL DEFAULT 'AKTIF',
        phone TEXT DEFAULT '',
        address TEXT DEFAULT '',
        fcm_token TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX uniq_users_email ON users(email)');

    await db.execute('''
      CREATE TABLE produk (
        id TEXT PRIMARY KEY,
        kode TEXT NOT NULL,
        nama TEXT NOT NULL,
        kategori TEXT DEFAULT '',
        sub_kategori TEXT DEFAULT '',
        harga_beli REAL NOT NULL DEFAULT 0,
        harga_jual REAL NOT NULL DEFAULT 0,
        harga_jual_2 REAL NOT NULL DEFAULT 0,
        stok REAL NOT NULL DEFAULT 0,
        satuan TEXT DEFAULT 'PCS',
        foto TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'AKTIF',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_produk_kode ON produk(kode)');
    await db.execute('CREATE INDEX idx_produk_status ON produk(status)');


    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_settings_key ON settings(key)');

    await db.execute('''
      CREATE TABLE transaksi (
        id TEXT PRIMARY KEY,
        invoice TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        kasir_email TEXT NOT NULL,
        kasir_name TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        diskon REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        bayar REAL NOT NULL DEFAULT 0,
        kembalian REAL NOT NULL DEFAULT 0,
        metode TEXT NOT NULL DEFAULT 'CASH',
        status TEXT NOT NULL DEFAULT 'SELESAI',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_transaksi_invoice ON transaksi(invoice)');
    await db.execute('CREATE INDEX idx_transaksi_tanggal ON transaksi(tanggal)');

    await db.execute('''
      CREATE TABLE transaksi_detail (
        id TEXT PRIMARY KEY,
        transaksi_id TEXT NOT NULL,
        invoice TEXT DEFAULT '',
        produk_id TEXT NOT NULL,
        kode TEXT DEFAULT '',
        nama TEXT DEFAULT '',
        qty REAL NOT NULL DEFAULT 0,
        harga REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_td_transaksi_id ON transaksi_detail(transaksi_id)');

    await db.execute('''
      CREATE TABLE pengeluaran (
        id TEXT PRIMARY KEY,
        tanggal TEXT NOT NULL,
        keterangan TEXT NOT NULL,
        jumlah REAL NOT NULL DEFAULT 0,
        kasir_name TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_pengeluaran_tanggal ON pengeluaran(tanggal)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        user_name TEXT,
        action TEXT,
        entity TEXT,
        entity_id TEXT,
        details TEXT,
        created_at TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0,
        last_modified TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier (
        id TEXT PRIMARY KEY,
        nama_pt TEXT NOT NULL,
        nomor TEXT NOT NULL,
        alamat TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_supplier_nama ON supplier(nama_pt)');

    await db.execute('''
      CREATE TABLE inventaris (
        id TEXT PRIMARY KEY,
        nama_barang TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        kondisi TEXT NOT NULL,
        keterangan TEXT,
        status TEXT NOT NULL DEFAULT 'AKTIF',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier', 'inventaris'];
    for (final table in tables) {
      await db.execute("ALTER TABLE $table ADD COLUMN sync_status INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE $table ADD COLUMN last_modified TEXT DEFAULT ''");
      await db.execute("ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0");
    }

    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Versi 1 → 2: tambah kolom foto ke tabel produk
      await db.execute("ALTER TABLE produk ADD COLUMN foto TEXT DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pengeluaran (
          id TEXT PRIMARY KEY,
          tanggal TEXT NOT NULL,
          keterangan TEXT NOT NULL,
          jumlah REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pengeluaran_tanggal ON pengeluaran(tanggal)');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pengeluaran (
          id TEXT PRIMARY KEY,
          tanggal TEXT NOT NULL,
          keterangan TEXT NOT NULL,
          jumlah REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pengeluaran_tanggal ON pengeluaran(tanggal)');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier (
          id TEXT PRIMARY KEY,
          nama_pt TEXT NOT NULL,
          nomor TEXT NOT NULL,
          alamat TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplier_nama ON supplier(nama_pt)');
    }
    if (oldVersion < 6) {
      final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier'];
      for (final table in tables) {
        await db.execute("ALTER TABLE $table ADD COLUMN sync_status INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE $table ADD COLUMN last_modified TEXT DEFAULT ''");
        await db.execute("ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0");
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventaris (
          id TEXT PRIMARY KEY,
          nama_barang TEXT NOT NULL,
          jumlah INTEGER NOT NULL,
          kondisi TEXT NOT NULL,
          keterangan TEXT,
          status TEXT NOT NULL DEFAULT 'AKTIF',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 0,
          last_modified TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute("ALTER TABLE users ADD COLUMN phone TEXT DEFAULT ''");
      await db.execute("ALTER TABLE users ADD COLUMN address TEXT DEFAULT ''");
    }
    if (oldVersion < 10) {
      await db.execute("ALTER TABLE pengeluaran ADD COLUMN kasir_name TEXT DEFAULT ''");
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id TEXT PRIMARY KEY,
          user_name TEXT,
          action TEXT,
          entity TEXT,
          entity_id TEXT,
          details TEXT,
          created_at TEXT NOT NULL,
          sync_status INTEGER NOT NULL DEFAULT 0,
          last_modified TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 12) {
      await db.execute("ALTER TABLE produk ADD COLUMN sub_kategori TEXT DEFAULT ''");
    }
    if (oldVersion < 13) {
      await db.execute("ALTER TABLE users ADD COLUMN fcm_token TEXT DEFAULT ''");
    }
    if (oldVersion < 14) {
      await mergeHotIceProducts(db);
    }
    if (oldVersion < 15) {
      await db.execute("ALTER TABLE produk ADD COLUMN harga_jual_2 REAL DEFAULT 0");
    }
  }

  /// Membersihkan dan menggabungkan produk-produk minuman yang terlanjur terpisah
  /// menjadi dua produk (misal: 'Kopi Susu Hot' dan 'Kopi Susu Ice') menjadi 1 produk utama 'Kopi Susu',
  /// sehingga pilihan Panas / Dingin dapat dipilih secara interaktif di layar kasir.
  static Future<int> mergeHotIceProducts(Database db) async {
    try {
      final rows = await db.query(
        'produk',
        where: "status != 'HAPUS' AND is_deleted = 0",
      );

      if (rows.isEmpty) return 0;

      // Helper pembersih nama produk
      String cleanDrinkName(String original) {
        String name = original.trim();
        // 1. Hapus akhiran dalam kurung: (Hot), (Ice), (Panas), (Dingin), (Hangat), (Cold), (Iced), (Hot/Ice), (Ice/Hot)
        name = name.replaceAll(
          RegExp(r'\s*\(\s*(Hot|Ice|Iced|Dingin|Panas|Hangat|Cold|Hot/Ice|Ice/Hot)\s*\)', caseSensitive: false),
          '',
        );
        // 2. Hapus akhiran tanda strip / spasi: - Hot, - Ice, Hot, Ice, Panas, Dingin, Hangat, Cold, Iced di ujung nama
        name = name.replaceAll(
          RegExp(r'[\s\-]+(Hot|Ice|Iced|Dingin|Panas|Hangat|Cold)$', caseSensitive: false),
          '',
        );
        // 3. Hapus awalan: Es , Es-, Hot , Ice , Iced
        name = name.replaceAll(
          RegExp(r'^(Es|Hot|Ice|Iced)[\s\-]+', caseSensitive: false),
          '',
        );
        return name.trim();
      }

      bool isDrinkCategory(String kat, String subKat) {
        final k = kat.toLowerCase();
        final s = subKat.toLowerCase();
        return k.contains('minum') ||
            k.contains('drink') ||
            k.contains('beverage') ||
            k.contains('kopi') ||
            k.contains('coffee') ||
            k.contains('tea') ||
            k.contains('teh') ||
            k.contains('boba') ||
            k.contains('jus') ||
            k.contains('juice') ||
            s.contains('minum') ||
            s.contains('drink') ||
            s.contains('kopi') ||
            s.contains('teh');
      }

      // Kelompokkan produk minuman berdasarkan nama bersih
      final Map<String, List<Map<String, dynamic>>> drinkGroups = {};

      for (final r in rows) {
        final originalNama = (r['nama'] ?? '').toString();
        final kategori = (r['kategori'] ?? '').toString();
        final subKategori = (r['sub_kategori'] ?? '').toString();
        final isDrink = isDrinkCategory(kategori, subKategori) ||
            originalNama.toLowerCase().startsWith('es ') ||
            originalNama.toLowerCase().startsWith('hot ') ||
            originalNama.toLowerCase().startsWith('ice ') ||
            originalNama.toLowerCase().endsWith(' hot') ||
            originalNama.toLowerCase().endsWith(' ice') ||
            originalNama.toLowerCase().endsWith(' dingin') ||
            originalNama.toLowerCase().endsWith(' panas') ||
            originalNama.toLowerCase().endsWith(' hangat') ||
            originalNama.toLowerCase().contains('(hot)') ||
            originalNama.toLowerCase().contains('(ice)');

        if (isDrink) {
          final cleaned = cleanDrinkName(originalNama);
          if (cleaned.isNotEmpty) {
            final key = cleaned.toLowerCase();
            drinkGroups.putIfAbsent(key, () => []).add({
              ...r,
              'cleanedNama': cleaned,
            });
          }
        }
      }

      int mergedCount = 0;
      final now = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      for (final entry in drinkGroups.entries) {
        final items = entry.value;
        if (items.isEmpty) continue;

        if (items.length > 1) {
          // Ada lebih dari 1 produk yang sama (misal 1 Hot, 1 Ice) -> Gabungkan jadi 1 produk
          // Prioritaskan yang punya foto atau yang id-nya pertama
          items.sort((a, b) {
            final aHasFoto = (a['foto'] ?? '').toString().isNotEmpty ? 1 : 0;
            final bHasFoto = (b['foto'] ?? '').toString().isNotEmpty ? 1 : 0;
            return bHasFoto.compareTo(aHasFoto);
          });

          final primary = items.first;
          final duplicates = items.sublist(1);
          final cleanedName = primary['cleanedNama'] as String;

          // Hitung total stok gabungan
          double totalStok = 0;
          for (final it in items) {
            final s = it['stok'];
            if (s is num) totalStok += s.toDouble();
          }

          // Update produk utama
          await db.update(
            'produk',
            {
              'nama': cleanedName,
              'kategori': (primary['kategori'] ?? '').toString().isEmpty ? 'Minuman' : primary['kategori'],
              'stok': totalStok,
              'updated_at': now,
              'sync_status': 0,
              'last_modified': now,
            },
            where: 'id = ?',
            whereArgs: [primary['id']],
          );

          // Hapus produk duplikat
          for (final dup in duplicates) {
            await db.update(
              'produk',
              {
                'status': 'HAPUS',
                'is_deleted': 1,
                'sync_status': 0,
                'last_modified': now,
              },
              where: 'id = ?',
              whereArgs: [dup['id']],
            );
            mergedCount++;
          }
        } else {
          // Hanya ada 1 item tapi namanya masih mengandung prefix/suffix (misal 'Es Teh Manis')
          final single = items.first;
          final originalNama = (single['nama'] ?? '').toString();
          final cleanedName = single['cleanedNama'] as String;

          if (cleanedName.isNotEmpty && cleanedName != originalNama) {
            await db.update(
              'produk',
              {
                'nama': cleanedName,
                'kategori': (single['kategori'] ?? '').toString().isEmpty ? 'Minuman' : single['kategori'],
                'updated_at': now,
                'sync_status': 0,
                'last_modified': now,
              },
              where: 'id = ?',
              whereArgs: [single['id']],
            );
          }
        }
      }

      return mergedCount;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    final adminHash = sha256.convert(utf8.encode(defaultAdminPassword)).toString();

    await db.insert('users', {
      'id': 'USR-00000001',
      'email': defaultAdminEmail,
      'name': 'Administrator',
      'password_hash': adminHash,
      'role': 'ADMIN',
      'status': 'AKTIF',
      'created_at': now,
      'updated_at': now,
    });

  }
}
