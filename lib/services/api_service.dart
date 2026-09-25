import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'foto_service.dart';
import 'local_helpers.dart';
import 'sync_service.dart';
import 'notification_service.dart';

export 'local_helpers.dart' show ApiException;

/// Versi OFFLINE dari ApiService.
///
/// Dulu class ini mengirim HTTP request ke `api.php` di hosting online.
/// Sekarang semua "action" yang sama (produk.list, transaksi.checkout, dst)
/// dikerjakan langsung di HP lewat SQLite (lihat db_helper.dart), tanpa
/// internet / server sama sekali. Kontrak `call()` / `callRaw()` sengaja
/// dipertahankan identik supaya seluruh layar (screens/*) tidak perlu
/// diubah satu pun baris kode.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _prefSession = 'kasirku_session_email';

  /// "Token" sekarang hanya menyimpan email user yang sedang login,
  /// dipakai sebagai penanda sesi lokal (tidak pernah dikirim ke mana pun).
  String? _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;
  String? get token => _token;

  Future<Database> get _db async => AppDatabase.instance.db;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefSession);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_prefSession);
    } else {
      await prefs.setString(_prefSession, token);
    }
  }

  Future<dynamic> call(String action, [Map<String, dynamic>? payload]) async {
    final res = await _dispatch(action, Map<String, dynamic>.from(payload ?? {}));
    final ok = res['ok'] == true;
    if (!ok) {
      throw ApiException(res['message']?.toString() ?? 'Terjadi kesalahan');
    }

    // Trigger auto-sync in background if it's a mutating action
    if (action.endsWith('.save') || 
        action.endsWith('.delete') || 
        action.endsWith('.checkout') || 
        action.endsWith('.refund') || 
        action.endsWith('.import') || 
        action.endsWith('.add') || 
        action.endsWith('.updateFCM') || 
        action.endsWith('Massal') ||
        action.startsWith('pengeluaran.') ||
        action.startsWith('inventaris.') ||
        action.startsWith('supplier.')) {
      SyncService.instance.syncData();
    }

    return res['data'];
  }

  /// Dipakai untuk action lama yang tidak dibungkus ok_()/fail_()
  /// (getDashboardChartData / getDashboardProfitChartData).
  Future<Map<String, dynamic>> callRaw(String action, [Map<String, dynamic>? payload]) async {
    final res = await _dispatch(action, Map<String, dynamic>.from(payload ?? {}));
    if (res.containsKey('ok') && res['ok'] == false) {
      throw ApiException(res['message']?.toString() ?? 'Terjadi kesalahan');
    }
    return res;
  }

  // ---------------------------------------------------------------------
  // DISPATCH
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _dispatch(String action, Map<String, dynamic> p) async {
    try {
      switch (action) {
        case 'auth.login':
          return await _authLogin(p);
        case 'me':
          return ok_((await _requireAuth()).toJson());

        case 'user.updateFCM':
          return await _userUpdateFCM(p);
        case 'dashboard.summary':
          return ok_(await _dashboardSummary());
        case 'getDashboardChartData':
          return await _dashboardChartData(p);
        case 'getDashboardProfitChartData':
          return await _dashboardProfitChartData(p);

        case 'monitoring.list':
          return await _monitoringList(p);
        case 'produk.list':
          return await _produkList(p);
        case 'produk.save':
          return await _produkSave(p);
        case 'produk.delete':
          return await _produkDelete(p);
        case 'produk.deleteMassal':
          return await _produkDeleteMassal(p);
        case 'produk.import':
          return await _produkImportMassal(p);

        case 'master.options':
          return await _masterOptions();
        case 'master.option.add':
          return await _masterOptionAdd(p);

        case 'transaksi.checkout':
          return await _transaksiCheckout(p);
        case 'transaksi.list':
          return await _transaksiList(p);
        case 'transaksi.delete':
          return await _transaksiDelete(p);
        case 'transaksi.refund':
          return await _transaksiRefund(p);

        case 'user.list':
          return await _userList(p);
        case 'user.save':
          return await _userSave(p);
        case 'user.delete':
          return await _userDelete(p);

        case 'pengeluaran.list':
          return await _pengeluaranList(p);
        case 'pengeluaran.save':
          return await _pengeluaranSave(p);
        case 'pengeluaran.delete':
          return await _pengeluaranDelete(p);

        case 'supplier.list':
          return await _supplierList(p);
        case 'supplier.save':
          return await _supplierSave(p);
        case 'supplier.delete':
          return await _supplierDelete(p);

        case 'inventaris.list':
          return await _inventarisList(p);
        case 'inventaris.save':
          return await _inventarisSave(p);
        case 'inventaris.delete':
          return await _inventarisDelete(p);

        case 'moneyku.summary':
          return await _moneykuSummary(p);

        default:
          return fail_('Action tidak ditemukan');
      }
    } on ApiException catch (e) {
      return fail_(e.message);
    } catch (e) {
      return fail_(e.toString());
    }
  }

  Map<String, dynamic> ok_(dynamic data, [String message = 'OK']) => {'ok': true, 'message': message, 'data': data};
  Map<String, dynamic> fail_(String message) => {'ok': false, 'message': message, 'data': null};

  // ---------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------

  Future<_Me> _requireAuth() async {
    if (!hasToken) {
      throw ApiException('Sesi sudah habis. Silakan login ulang.');
    }
    final db = await _db;
    final rows = await db.query('users', where: 'LOWER(email) = ? AND status = ?', whereArgs: [_token!.toLowerCase(), 'AKTIF']);
    if (rows.isEmpty) {
      await setToken(null);
      throw ApiException('Sesi sudah habis. Silakan login ulang.');
    }
    final u = rows.first;
    return _Me(email: u['email'] as String, name: u['name'] as String, role: u['role'] as String);
  }

  Future<_Me> _assertAdmin() async {
    final me = await _requireAuth();
    if (me.role.toUpperCase() != 'ADMIN') {
      throw ApiException('Akses ditolak: Hanya role Admin yang dapat mengubah atau mengelola produk');
    }
    return me;
  }

  
  Future<void> _logAudit(dynamic db, String userName, String action, String entity, String entityId, String details) async {
    await db.insert('audit_logs', {
      'id': uid_('ADT'),
      'user_name': userName,
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'details': details,
      'created_at': now_(),
      'sync_status': 0,
      'last_modified': now_(),
      'is_deleted': 0,
    });
    
    // Kirim Push Notification ke Admin (dieksekusi di background agar tidak memblokir UI)
    NotificationService.instance.notifyAdmins(db, userName, action, entity, details);

    // Trigger sinkronisasi instan ke cloud Supabase
    SyncService.instance.syncData();
  }

  Future<Map<String, dynamic>> _monitoringList(Map<String, dynamic> p) async {
    await _assertAdmin();
    final db = await _db;
    final startDate = s_(p['start_date']);
    final endDate = s_(p['end_date']);

    String whereClause = '1 = 1';
    List<dynamic> whereArgs = [];

    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      whereClause += ' AND created_at >= ? AND created_at <= ?';
      whereArgs.addAll(['$startDate 00:00:00', '$endDate 23:59:59']);
    }

    // Limit to 500 rows maximum to prevent memory overload in the UI
    final rows = await db.query('audit_logs', where: whereClause, whereArgs: whereArgs, orderBy: 'created_at DESC', limit: 500);
    return ok_({'data': rows});
  }
  Future<Map<String, dynamic>> _authLogin(Map<String, dynamic> p) async {
    final email = s_(p['email']).toLowerCase();
    final password = s_(p['password']);

    if (email.isEmpty || password.isEmpty) {
      return fail_('Email dan password wajib diisi');
    }

    final db = await _db;
    final rows = await db.query('users', where: 'LOWER(email) = ? AND status = ?', whereArgs: [email, 'AKTIF']);
    if (rows.isEmpty) {
      return fail_('User tidak ditemukan atau tidak aktif');
    }
    final user = rows.first;

    if (user['password_hash'] != hashPw_(password)) {
      return fail_('Password salah');
    }

    await setToken(user['email'] as String);

    return ok_({
      'token': user['email'],
      'me': {'email': user['email'], 'name': user['name'], 'role': user['role']},
    });
  }

  Future<Map<String, dynamic>> _userUpdateFCM(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final fcmToken = s_(p['fcm_token']);
    final db = await _db;
    
    await db.update(
      'users',
      {
        'fcm_token': fcmToken,
        'sync_status': 0,
        'last_modified': now_(),
      },
      where: 'email = ?',
      whereArgs: [me.email],
    );
    return ok_(null);
  }

  // ---------------------------------------------------------------------
  // DASHBOARD
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _dashboardSummary() async {
    await _requireAuth();
    final db = await _db;

    final today = todayYmd_();
    final yesterday = () {
      final d = DateTime.now().subtract(const Duration(days: 1));
      return '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
    }();
    final thisMonth = today.substring(0, 7);

    // 1. Transaction and Profit Summary
    const trxQuery = '''
      SELECT 
        SUM(t.total) AS totalTrans,
        SUM(CASE WHEN t.tanggal LIKE ? THEN t.total ELSE 0 END) AS transHariIni,
        SUM(CASE WHEN t.tanggal LIKE ? THEN t.total ELSE 0 END) AS transKemarin,
        SUM(CASE WHEN t.tanggal LIKE ? THEN t.total ELSE 0 END) AS transBulanIni,
        SUM(IFNULL(d.profit_item, 0)) AS totalProfit,
        SUM(CASE WHEN t.tanggal LIKE ? THEN IFNULL(d.profit_item, 0) ELSE 0 END) AS profitHariIni
      FROM transaksi t
      LEFT JOIN (
        SELECT td.transaksi_id, SUM((td.harga - IFNULL(p.harga_beli, 0)) * td.qty) AS profit_item
        FROM transaksi_detail td
        LEFT JOIN produk p ON td.produk_id = p.id
        WHERE td.is_deleted = 0
        GROUP BY td.transaksi_id
      ) d ON d.transaksi_id = t.id
      WHERE t.status = 'SELESAI' AND t.is_deleted = 0
    ''';
    
    final trxRows = await db.rawQuery(trxQuery, ['$today%', '$yesterday%', '$thisMonth%', '$today%']);
    final trxData = trxRows.isNotEmpty ? trxRows.first : {};

    double totalTrans = num_(trxData['totalTrans']);
    double transHariIni = num_(trxData['transHariIni']);
    double transKemarin = num_(trxData['transKemarin']);
    double transBulanIni = num_(trxData['transBulanIni']);
    double totalProfit = num_(trxData['totalProfit']);
    double profitHariIni = num_(trxData['profitHariIni']);

    // 2. Pengeluaran Summary
    const pengeluaranQuery = '''
      SELECT 
        SUM(jumlah) AS totalPengeluaran,
        SUM(CASE WHEN tanggal LIKE ? THEN jumlah ELSE 0 END) AS pengeluaranHariIni
      FROM pengeluaran
      WHERE is_deleted = 0
    ''';
    final pengeluaranRows = await db.rawQuery(pengeluaranQuery, ['$today%']);
    final pData = pengeluaranRows.isNotEmpty ? pengeluaranRows.first : {};
    
    totalProfit -= num_(pData['totalPengeluaran']);
    profitHariIni -= num_(pData['pengeluaranHariIni']);

    // 3. Produk Aktif
    const produkQuery = "SELECT COUNT(*) as count FROM produk WHERE status = 'AKTIF' AND is_deleted = 0";
    final produkRows = await db.rawQuery(produkQuery);
    int totalProdukAktif = produkRows.isNotEmpty ? (produkRows.first['count'] as int? ?? 0) : 0;

    return {
      'transHariIni': transHariIni,
      'transKemarin': transKemarin,
      'transBulanIni': transBulanIni,
      'profitHariIni': profitHariIni,
      'totalTrans': totalTrans,
      'totalProfit': totalProfit,
      'totalProdukAktif': totalProdukAktif,
    };
  }

  Future<Map<String, dynamic>> _dashboardChartData(Map<String, dynamic> filter) async {
    try {
      final db = await _db;
      final fType = s_(filter['type']).isEmpty ? 'bulan' : s_(filter['type']);
      final fValue = s_(filter['value']);
      
      String query = "SELECT tanggal, SUM(total) as total FROM transaksi WHERE status = 'SELESAI' AND is_deleted = 0";
      List<dynamic> args = [];
      
      if (fType == 'hari' && fValue.isNotEmpty) {
         query += " AND tanggal LIKE ?";
         args.add('$fValue-%');
      } else if (fType == 'bulan' && fValue.isNotEmpty) {
         query += " AND tanggal LIKE ?";
         args.add('$fValue-%');
      } else if (fType == 'tahun' && fValue.isNotEmpty) {
         query += " AND tanggal LIKE ?";
         args.add('$fValue-%');
      }
      
      query += " GROUP BY tanggal ORDER BY tanggal ASC";
      
      final rows = await db.rawQuery(query, args);
      final rekap = <String, double>{};
      
      for (final row in rows) {
         final tglRaw = s_(row['tanggal']);
         final total = num_(row['total']);
         if (tglRaw.isEmpty) continue;
         
         final ts = DateTime.tryParse(tglRaw);
         if (ts == null) continue;
         
         final tahun = ts.year;
         String label;
         
         if (fType == 'hari') {
           label = '${pad2(ts.day)} ${namaBulanSingkatId_(ts.month)}';
         } else if (fType == 'bulan') {
           label = '${namaBulanId_(ts.month)} $tahun';
         } else {
           label = tahun.toString();
         }
         
         rekap[label] = (rekap[label] ?? 0) + total;
      }
      
      return {'labels': rekap.keys.toList(), 'data': rekap.values.toList()};
    } catch (_) {
      return {'labels': [], 'data': []};
    }
  }

  Future<Map<String, dynamic>> _dashboardProfitChartData(Map<String, dynamic> filter) async {
    try {
      final db = await _db;
      final fType = s_(filter['type']).isEmpty ? 'bulan' : s_(filter['type']);
      final fValue = s_(filter['value']);
      
      String query = '''
        SELECT t.tanggal, SUM((td.harga - IFNULL(p.harga_beli, 0)) * td.qty) AS profit
        FROM transaksi t
        INNER JOIN transaksi_detail td ON td.transaksi_id = t.id
        LEFT JOIN produk p ON td.produk_id = p.id
        WHERE t.status = 'SELESAI' AND t.is_deleted = 0 AND td.is_deleted = 0
      ''';
      List<dynamic> args = [];
      
      if (fType == 'hari' && fValue.isNotEmpty) {
         query += " AND t.tanggal LIKE ?";
         args.add('$fValue-%');
      } else if (fType == 'bulan' && fValue.isNotEmpty) {
         query += " AND t.tanggal LIKE ?";
         args.add('$fValue-%');
      } else if (fType == 'tahun' && fValue.isNotEmpty) {
         query += " AND t.tanggal LIKE ?";
         args.add('$fValue-%');
      }
      
      query += " GROUP BY t.tanggal ORDER BY t.tanggal ASC";
      
      final rows = await db.rawQuery(query, args);
      final rekap = <String, double>{};
      
      for (final row in rows) {
         final tglRaw = s_(row['tanggal']);
         final profit = num_(row['profit']);
         if (tglRaw.isEmpty) continue;
         
         final ts = DateTime.tryParse(tglRaw);
         if (ts == null) continue;
         
         final tahun = ts.year;
         String label;
         
         if (fType == 'hari') {
           label = '${pad2(ts.day)} ${namaBulanSingkatId_(ts.month)}';
         } else if (fType == 'bulan') {
           label = '${namaBulanId_(ts.month)} $tahun';
         } else {
           label = tahun.toString();
         }
         
         rekap[label] = (rekap[label] ?? 0) + profit;
      }
      
      return {'labels': rekap.keys.toList(), 'data': rekap.values.toList()};
    } catch (_) {
      return {'labels': [], 'data': []};
    }
  }

  // ---------------------------------------------------------------------
  // PRODUK
  // ---------------------------------------------------------------------

  Map<String, dynamic> _rowToProduk(Map<String, dynamic> r) => {
        'id': r['id'],
        'kode': r['kode'],
        'nama': r['nama'],
        'kategori': r['kategori'],
        'subKategori': r['sub_kategori'] ?? '',
        'hargaBeli': num_(r['harga_beli']),
        'hargaJual': num_(r['harga_jual']),
        'hargaJual2': num_(r['harga_jual_2']),
        'stok': num_(r['stok']),
        'satuan': r['satuan'],
        'foto': r['foto'] ?? '',
        'status': r['status'],
        'createdAt': r['created_at'],
        'updatedAt': r['updated_at'],
      };

  Future<Map<String, dynamic>> _produkList(Map<String, dynamic> p) async {
    await _requireAuth();
    final q = s_(p['q']).toLowerCase();
    final db = await _db;

    String query = "SELECT * FROM produk WHERE status != 'HAPUS' AND is_deleted = 0";
    List<dynamic> args = [];

    if (q.isNotEmpty) {
      query += " AND (LOWER(nama) LIKE ? OR LOWER(kode) LIKE ? OR LOWER(kategori) LIKE ?)";
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }

    query += " ORDER BY LOWER(nama) ASC";

    final rows = await db.rawQuery(query, args);

    return ok_(rows.map(_rowToProduk).toList());
  }

  Future<Map<String, dynamic>> _produkSave(Map<String, dynamic> p) async {
    final me = await _assertAdmin();

    final id = s_(p['id']).isNotEmpty ? s_(p['id']) : uid_('PRD');
    final kode = s_(p['kode']);
    final nama = s_(p['nama']);
    final kategori = s_(p['kategori']);
    final subKategori = s_(p['subKategori']);
    final hargaBeli = num_(p['hargaBeli']);
    final hargaJual = num_(p['hargaJual']);
    final hargaJual2 = num_(p['hargaJual2']);
    final stok = num_(p['stok']);
    final satuan = s_(p['satuan']).isNotEmpty ? s_(p['satuan']) : 'PCS';
    // foto bisa berupa path baru, path lama (tidak berubah), atau kosong
    final foto = s_(p['foto']);

    if (kode.isEmpty) return fail_('Kode produk wajib diisi');
    if (nama.isEmpty) return fail_('Nama produk wajib diisi');
    if (hargaJual <= 0) return fail_('Harga jual wajib lebih dari 0');

    final db = await _db;

    final dup = await db.query('produk',
        where: 'UPPER(kode) = ? AND id != ? AND status != ?', whereArgs: [kode.toUpperCase(), id, 'HAPUS']);
    if (dup.isNotEmpty) return fail_('Kode produk sudah digunakan');

    final existRows = await db.query('produk', where: 'id = ?', whereArgs: [id]);
    final existing = existRows.isNotEmpty ? existRows.first : null;
    final now = now_();

    if (existing != null) {
      await db.update(
        'produk',
        {
          'kode': kode,
          'nama': nama,
          'kategori': kategori,
          'sub_kategori': subKategori,
          'harga_beli': hargaBeli,
          'harga_jual': hargaJual,
          'harga_jual_2': hargaJual2,
          'stok': stok,
          'satuan': satuan,
          'foto': foto,
          'status': 'AKTIF',
          'updated_at': now,
          'sync_status': 0,
          'last_modified': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert('produk', {
        'id': id,
        'kode': kode,
        'nama': nama,
        'kategori': kategori,
        'sub_kategori': subKategori,
        'harga_beli': hargaBeli,
        'harga_jual': hargaJual,
        'harga_jual_2': hargaJual2,
        'stok': stok,
        'satuan': satuan,
        'foto': foto,
        'status': 'AKTIF',
        'created_at': now,
        'updated_at': now,
        'sync_status': 0,
        'last_modified': now,
      });
    }
    final createdAt = existing != null ? existing['created_at'] : now;

    await _logAudit(db, me.name, existing != null ? 'UPDATE' : 'CREATE', 'Produk', id, 'Nama Produk: $nama, Stok: $stok, Harga: $hargaJual');

    return ok_({
      'id': id, 'kode': kode, 'nama': nama, 'kategori': kategori,
      'hargaBeli': hargaBeli, 'hargaJual': hargaJual, 'stok': stok,
      'satuan': satuan, 'foto': foto, 'status': 'AKTIF',
      'createdAt': createdAt, 'updatedAt': now,
    }, 'Produk berhasil disimpan');
  }

  Future<Map<String, dynamic>> _produkDelete(Map<String, dynamic> p) async {
    final me = await _assertAdmin();

    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID produk wajib diisi');

    final db = await _db;
    final rows = await db.query('produk', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return fail_('Produk tidak ditemukan');

    // Hapus file foto dari disk sebelum soft-delete
    final fotoPath = rows.first['foto']?.toString();
    await FotoService.instance.deletePhoto(fotoPath);

    await db.update('produk', {'status': 'HAPUS', 'foto': '', 'updated_at': now_(), 'sync_status': 0, 'last_modified': now_(), 'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    await _logAudit(db, me.name, 'DELETE', 'Produk', id, 'Produk ID: $id dihapus');
    return ok_(null, 'Produk berhasil dihapus');
  }

  Future<Map<String, dynamic>> _produkDeleteMassal(Map<String, dynamic> p) async {
    await _assertAdmin();

    final rawIds = p['ids'];
    if (rawIds is! List || rawIds.isEmpty) return fail_('Tidak ada produk yang dipilih');

    final ids = rawIds.map((e) => s_(e)).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return fail_('Tidak ada produk yang dipilih');

    final db = await _db;
    final now = now_();
    var jumlahSukses = 0;
    for (final id in ids) {
      // Ambil path foto sebelum dihapus
      final rows = await db.query('produk', columns: ['foto'], where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        await FotoService.instance.deletePhoto(rows.first['foto']?.toString());
      }
      final count = await db.update(
        'produk',
        {'status': 'HAPUS', 'foto': '', 'updated_at': now, 'sync_status': 0, 'last_modified': now, 'is_deleted': 1},
        where: 'id = ? AND status != ?',
        whereArgs: [id, 'HAPUS'],
      );
      if (count > 0) jumlahSukses++;
    }

    if (jumlahSukses == 0) return fail_('Produk tidak ditemukan atau sudah terhapus');
    return ok_({'jumlah': jumlahSukses}, '$jumlahSukses produk berhasil dihapus');
  }

  Future<Map<String, dynamic>> _produkImportMassal(Map<String, dynamic> p) async {
    try {
      await _assertAdmin();
      
      final dataArr = p['data'];
      if (dataArr is! List || dataArr.isEmpty) {
        return fail_('Data import kosong atau format tidak valid');
      }

      final db = await _db;
      final now = now_();
      var jumlahSukses = 0;

      await db.transaction((txn) async {
        // Prepare to check existing categories & units
        final existingSettings = await txn.query('settings');
        final existingKategori = existingSettings
            .where((r) => s_(r['key']).toUpperCase() == 'KATEGORI_INDUK' || s_(r['key']).toUpperCase() == 'KATEGORI_PRODUK')
            .map((r) => s_(r['value']).toLowerCase())
            .toSet();
        existingKategori.addAll(['makanan', 'minuman', 'snack/food', 'lainnya']);

        final existingSatuan = existingSettings
            .where((r) => s_(r['key']).toUpperCase() == 'SATUAN_PRODUK')
            .map((r) => s_(r['value']).toLowerCase())
            .toSet();
        existingSatuan.addAll(['cup', 'pcs', 'porsi', 'botol', 'pack', 'slice']);

        for (final raw in dataArr) {
          final item = Map<String, dynamic>.from(raw as Map);
          final nama = s_(item['nama'] ?? item['NAMA'] ?? item['nama_produk'] ?? item['nama_barang']);
          if (nama.isEmpty) continue;

          var kode = s_(item['kode'] ?? item['KODE'] ?? item['kode_barang'] ?? item['sku']);
          if (kode.isEmpty) {
            kode = uid_('BRG');
          }
          final kategori = s_(item['kategori'] ?? item['KATEGORI'] ?? item['kategori_produk']).isNotEmpty 
              ? s_(item['kategori'] ?? item['KATEGORI'] ?? item['kategori_produk']) 
              : 'Lainnya';
          final subKategori = s_(item['subKategori'] ?? item['sub_kategori'] ?? item['SUB_KATEGORI']);
          final hargaBeli = num_(item['hargabeli'] ?? item['hargaBeli'] ?? item['harga_beli'] ?? item['hpp'] ?? 0);
          final hargaJual = num_(item['hargajual'] ?? item['hargaJual'] ?? item['harga_jual'] ?? 0);
          final satuanRaw = s_(item['satuan'] ?? item['SATUAN'] ?? item['unit']);
          final satuan = (satuanRaw.isNotEmpty ? satuanRaw : 'PCS').toUpperCase();

          // Add to settings if not exist
          if (kategori.isNotEmpty && !existingKategori.contains(kategori.toLowerCase())) {
            existingKategori.add(kategori.toLowerCase());
            await txn.insert('settings', {
              'key': 'KATEGORI_INDUK',
              'value': kategori,
              'updated_at': now,
              'sync_status': 0,
              'last_modified': now,
              'is_deleted': 0,
            });
          }

          if (satuan.isNotEmpty && !existingSatuan.contains(satuan.toLowerCase())) {
            existingSatuan.add(satuan.toLowerCase());
            await txn.insert('settings', {
              'key': 'SATUAN_PRODUK',
              'value': satuan,
              'updated_at': now,
              'sync_status': 0,
              'last_modified': now,
              'is_deleted': 0,
            });
          }

          // Cek apakah produk dengan kode tersebut sudah ada di SQLite
          final existing = await txn.query(
            'produk', 
            where: 'UPPER(kode) = ? AND status != ? AND is_deleted = 0', 
            whereArgs: [kode.toUpperCase(), 'HAPUS']
          );

          if (existing.isNotEmpty) {
            final existId = existing.first['id'] as String;
            await txn.update(
              'produk',
              {
                'nama': nama,
                'kategori': kategori,
                'sub_kategori': subKategori,
                'harga_beli': hargaBeli,
                'harga_jual': hargaJual,
                'satuan': satuan,
                'status': 'AKTIF',
                'updated_at': now,
                'sync_status': 0,
                'last_modified': now,
              },
              where: 'id = ?',
              whereArgs: [existId],
            );
          } else {
            await txn.insert('produk', {
              'id': uid_('PRD'),
              'kode': kode,
              'nama': nama,
              'kategori': kategori,
              'sub_kategori': subKategori,
              'harga_beli': hargaBeli,
              'harga_jual': hargaJual,
              'stok': 0,
              'satuan': satuan,
              'foto': '',
              'status': 'AKTIF',
              'created_at': now,
              'updated_at': now,
              'sync_status': 0,
              'last_modified': now,
            });
          }
          jumlahSukses++;
        }
      });

      return ok_(null, 'Berhasil mengimport $jumlahSukses produk ke penyimpanan HP.');
    } catch (e) {
      return fail_('Gagal melakukan import: $e');
    }
  }

  // ---------------------------------------------------------------------
  // MASTER OPTIONS (kategori & satuan produk)
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _masterOptions() async {
    await _requireAuth();
    final db = await _db;
    final rows = await db.query('settings');

    final kategoriInduk = <String>[];
    final kategoriSub = <String>[];
    final satuan = <String>[];

    for (final r in rows) {
      final key = s_(r['key']).toUpperCase();
      final value = s_(r['value']);
      if (value.isEmpty) continue;
      if (key == 'KATEGORI_INDUK') kategoriInduk.add(value);
      if (key == 'KATEGORI_SUB') kategoriSub.add(value);
      if (key == 'SATUAN_PRODUK') satuan.add(value);
      // Backward compat: baca KATEGORI_PRODUK lama sebagai kategoriInduk
      if (key == 'KATEGORI_PRODUK') kategoriInduk.add(value);
    }

    final defaultKategoriInduk = ['Makanan', 'Minuman', 'Snack/Food', 'Lainnya'];
    final defaultSatuan = ['Cup', 'Pcs', 'Porsi', 'Botol', 'Pack', 'Slice'];
    
    // Auto-detect dari tabel produk agar otomatis kebaca
    final produkRows = await db.rawQuery('SELECT DISTINCT kategori, sub_kategori FROM produk WHERE status != "HAPUS"');
    for (final r in produkRows) {
      final k = s_(r['kategori']).trim();
      final s = s_(r['sub_kategori']).trim();
      if (k.isNotEmpty) kategoriInduk.add(k);
      if (s.isNotEmpty) kategoriSub.add(s);
    }

    final indukFinal = <String>{...defaultKategoriInduk, ...kategoriInduk}.toList();
    final subFinal = <String>{...kategoriSub}.toList();
    final satuanFinal = <String>{...defaultSatuan, ...satuan}.toList();
    return ok_({
      'kategoriInduk': uniqueSort_(indukFinal),
      'kategoriSub': uniqueSort_(subFinal),
      // Backward-compat key — berisi gabungan semua kategori flat
      'kategori': uniqueSort_([...indukFinal, ...subFinal]),
      'satuan': uniqueSort_(satuanFinal),
    });
  }

  Future<Map<String, dynamic>> _masterOptionAdd(Map<String, dynamic> p) async {
    await _requireAuth();

    final type = s_(p['type']).toUpperCase();
    final value = s_(p['value']);

    if (type.isEmpty) return fail_('Tipe master wajib diisi');
    if (value.isEmpty) return fail_('Nama pilihan wajib diisi');

    String key;
    if (type == 'KATEGORI_INDUK') {
      key = 'KATEGORI_INDUK';
    } else if (type == 'KATEGORI_SUB') {
      key = 'KATEGORI_SUB';
    } else if (type == 'KATEGORI') {
      // Backward compat
      key = 'KATEGORI_INDUK';
    } else if (type == 'SATUAN') {
      key = 'SATUAN_PRODUK';
    } else {
      return fail_('Tipe master tidak valid');
    }

    final db = await _db;
    final dup = await db.query('settings', where: 'key = ? AND UPPER(value) = ?', whereArgs: [key, value.toUpperCase()]);
    if (dup.isNotEmpty) return fail_('Data sudah ada');

    await db.insert('settings', {'key': key, 'value': value, 'updated_at': now_(), 'sync_status': 0, 'last_modified': now_()});
    return ok_({'type': type, 'value': value}, 'Data berhasil ditambahkan');
  }

  // ---------------------------------------------------------------------
  // TRANSAKSI
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _transaksiCheckout(Map<String, dynamic> p) async {
    final me = await _requireAuth();

    final rawItems = p['items'];
    final items = rawItems is List ? rawItems : [];
    final bayar = num_(p['bayar']);
    final diskon = num_(p['diskon']);
    final metode = s_(p['metode']).isNotEmpty ? s_(p['metode']) : 'CASH';

    if (items.isEmpty) return fail_('Keranjang masih kosong');

    final db = await _db;

    try {
      Map<String, dynamic>? result;

      await db.transaction((txn) async {
        double subtotal = 0;
        final finalItems = <Map<String, dynamic>>[];

        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw as Map);
          final produkId = s_(item['produkId']);
          final qty = num_(item['qty']);
          final customNama = s_(item['nama']);
          final varian = s_(item['varian']);

          if (produkId.isEmpty || qty <= 0) throw ApiException('Item transaksi tidak valid');

          final rows = await txn.query('produk', where: 'id = ? AND status = ?', whereArgs: [produkId, 'AKTIF']);
          final produk = rows.isNotEmpty ? rows.first : null;
          if (produk == null) throw ApiException('Produk tidak ditemukan');

          final rawHarga = num_(item['harga']);
          final hargaJual1 = num_(produk['harga_jual']);
          final hargaJual2 = num_(produk['harga_jual_2']);

          double harga = hargaJual1;
          if (rawHarga > 0) {
            harga = rawHarga;
          } else if (varian.isNotEmpty && (varian == 'Dingin' || varian == 'Tanpa Nasi') && hargaJual2 > 0) {
            harga = hargaJual2;
          }

          if (harga <= 0) throw ApiException('Harga jual produk ${produk['nama']} tidak valid');

          final itemSubtotal = harga * qty;
          subtotal += itemSubtotal;

          String displayName = customNama.isNotEmpty ? customNama : s_(produk['nama']);
          if (displayName == s_(produk['nama']) && varian.isNotEmpty) {
            displayName = '${produk['nama']} ($varian)';
          }

          finalItems.add({
            'produk': produk,
            'displayName': displayName,
            'varian': varian,
            'qty': qty,
            'harga': harga,
            'subtotal': itemSubtotal,
          });
        }

        final total = subtotal - diskon;
        if (total <= 0) throw ApiException('Total transaksi tidak valid');
        if (bayar < total) throw ApiException('Nominal bayar kurang');

        final transaksiId = uid_('TRX');
        final invoice = makeInvoice_();
        final tanggal = todayYmd_();
        final createdAt = now_();
        final kembalian = bayar - total;

        await txn.insert('transaksi', {
          'id': transaksiId, 'invoice': invoice, 'tanggal': tanggal,
          'kasir_email': me.email, 'kasir_name': me.name,
          'subtotal': subtotal, 'diskon': diskon, 'total': total, 'bayar': bayar,
          'kembalian': kembalian, 'metode': metode, 'status': 'SELESAI', 'created_at': now_(),
          'sync_status': 0, 'last_modified': now_(),
        });

        for (final it in finalItems) {
          final produk = it['produk'] as Map<String, dynamic>;
          final itemNama = it['displayName'] as String;
          await txn.insert('transaksi_detail', {
            'id': uid_('DTL'), 'transaksi_id': transaksiId, 'invoice': invoice,
            'produk_id': produk['id'], 'kode': produk['kode'], 'nama': itemNama,
            'qty': it['qty'], 'harga': it['harga'], 'subtotal': it['subtotal'],
            'created_at': now_(),
            'sync_status': 0, 'last_modified': now_(),
          });
        }

        result = {
          'transaksiId': transaksiId, 'invoice': invoice, 'tanggal': tanggal,
          'createdAt': createdAt, 'kasirEmail': me.email, 'kasirName': me.name,
          'subtotal': subtotal, 'diskon': diskon, 'total': total, 'bayar': bayar,
          'kembalian': kembalian, 'metode': metode,
          'items': finalItems.map((it) => {
                'produkId': (it['produk'] as Map)['id'],
                'kode': (it['produk'] as Map)['kode'],
                'nama': it['displayName'],
                'varian': it['varian'],
                'qty': it['qty'],
                'harga': it['harga'],
                'subtotal': it['subtotal'],
              }).toList(),
        };
      });

      return ok_(result, 'Transaksi berhasil disimpan');
    } on ApiException catch (e) {
      return fail_(e.message);
    }
  }

  Future<Map<String, dynamic>> _transaksiList(Map<String, dynamic> p) async {
    await _requireAuth();
    final q = s_(p['q']).toLowerCase();
    final db = await _db;

    String query = '''
      SELECT 
        t.id, t.invoice, t.created_at, t.kasir_name, t.total, t.bayar, t.kembalian, t.metode, t.status,
        IFNULL(GROUP_CONCAT(d.nama, ', '), '-') AS namaBarang,
        IFNULL(SUM(d.qty), 0) AS jumlah
      FROM transaksi t
      LEFT JOIN transaksi_detail d ON d.transaksi_id = t.id AND d.is_deleted = 0
      WHERE t.is_deleted = 0
    ''';
    List<dynamic> args = [];

    if (q.isNotEmpty) {
      query += " AND (LOWER(t.invoice) LIKE ? OR LOWER(t.kasir_name) LIKE ? OR LOWER(t.metode) LIKE ?)";
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }

    query += " GROUP BY t.id ORDER BY t.created_at DESC";

    final rows = await db.rawQuery(query, args);

    final flatData = <Map<String, dynamic>>[];
    for (final r in rows) {
      flatData.add({
        'id': r['id'], 
        'invoice': r['invoice'], 
        'tanggal': r['created_at'],
        'namaBarang': r['namaBarang'], 
        'jumlah': num_(r['jumlah']), 
        'kasirName': r['kasir_name'],
        'total': num_(r['total']), 
        'bayar': num_(r['bayar']), 
        'kembalian': num_(r['kembalian']),
        'metode': s_(r['metode']).isNotEmpty ? r['metode'] : 'CASH', 
        'status': s_(r['status']).isNotEmpty ? r['status'] : 'SELESAI', 
        'createdAt': r['created_at'],
      });
    }

    return ok_(flatData);
  }

  Future<Map<String, dynamic>> _transaksiDelete(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID transaksi wajib diisi');

    final db = await _db;
    final trxRows = await db.query('transaksi', columns: ['id', 'invoice'], where: 'id = ?', whereArgs: [id]);
    if (trxRows.isEmpty) return fail_('Transaksi tidak ditemukan');
    final invoice = trxRows.first['invoice'];

    try {
      await db.transaction((txn) async {
        await txn.update('transaksi_detail', {'is_deleted': 1, 'sync_status': 0, 'last_modified': now_()}, where: 'transaksi_id = ?', whereArgs: [id]);
        await txn.update('transaksi', {'is_deleted': 1, 'sync_status': 0, 'last_modified': now_()}, where: 'id = ?', whereArgs: [id]);
      });

      await _logAudit(db, me.name, 'DELETE', 'Transaksi', id, 'Invoice: $invoice dihapus');
      return ok_(null, 'Transaksi $invoice berhasil dihapus');
    } catch (e) {
      return fail_('Gagal menghapus transaksi: $e');
    }
  }

  Future<Map<String, dynamic>> _transaksiRefund(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID transaksi wajib diisi');

    final db = await _db;
    final trxRows = await db.query('transaksi', columns: ['id', 'invoice', 'status'], where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (trxRows.isEmpty) return fail_('Transaksi tidak ditemukan');
    
    final row = trxRows.first;
    if (s_(row['status']) == 'REFUND') {
      return fail_('Transaksi ini sudah di-refund sebelumnya');
    }
    
    final invoice = row['invoice'];

    try {
      await db.transaction((txn) async {
        await txn.update('transaksi', {'status': 'REFUND', 'sync_status': 0, 'last_modified': now_()}, where: 'id = ?', whereArgs: [id]);
      });

      await _logAudit(db, me.name, 'REFUND', 'Transaksi', id, 'Invoice: $invoice di-refund');
      return ok_(null, 'Transaksi $invoice berhasil di-refund');
    } catch (e) {
      return fail_('Gagal melakukan refund transaksi: $e');
    }
  }

  // ---------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _userList(Map<String, dynamic> p) async {
    await _assertAdmin();
    final q = s_(p['q']).toLowerCase();
    final db = await _db;

    var rows = List<Map<String, Object?>>.of(
      await db.query('users', where: 'status != ? AND is_deleted = 0', whereArgs: ['HAPUS']),
    );

    if (q.isNotEmpty) {
      rows = rows.where((r) {
        return s_(r['email']).toLowerCase().contains(q) ||
            s_(r['name']).toLowerCase().contains(q) ||
            s_(r['role']).toLowerCase().contains(q) ||
            s_(r['status']).toLowerCase().contains(q);
      }).toList();
    }

    rows.sort((a, b) {
      final byName = s_(a['name']).toLowerCase().compareTo(s_(b['name']).toLowerCase());
      return byName != 0 ? byName : s_(a['email']).toLowerCase().compareTo(s_(b['email']).toLowerCase());
    });

    final safeRows = rows
        .map((r) => {
              'id': r['id'], 'email': r['email'], 'name': r['name'], 'role': r['role'],
              'status': r['status'], 'phone': r['phone'] ?? '', 'address': r['address'] ?? '', 'createdAt': r['created_at'], 'updatedAt': r['updated_at'],
            })
        .toList();

    return ok_(safeRows);
  }

  Future<Map<String, dynamic>> _userSave(Map<String, dynamic> p) async {
    await _assertAdmin();

    final id = s_(p['id']).isNotEmpty ? s_(p['id']) : uid_('USR');
    final email = s_(p['email']).toLowerCase();
    final name = s_(p['name']);
    final password = s_(p['password']);
    final role = s_(p['role']).toUpperCase();
    final status = s_(p['status']).toUpperCase().isNotEmpty ? s_(p['status']).toUpperCase() : 'AKTIF';
    final phone = s_(p['phone']);
    final address = s_(p['address']);

    if (email.isEmpty) return fail_('Email wajib diisi');
    if (name.isEmpty) return fail_('Nama wajib diisi');
    if (!['ADMIN', 'KASIR'].contains(role)) return fail_('Role tidak valid');
    if (!['AKTIF', 'NONAKTIF'].contains(status)) return fail_('Status tidak valid');

    final db = await _db;
    final existRows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    final existing = existRows.isNotEmpty ? existRows.first : null;

    if (existing == null && password.isEmpty) return fail_('Password wajib diisi untuk user baru');

    final dup = await db.query('users', where: 'LOWER(email) = ? AND id != ? AND status != ?', whereArgs: [email, id, 'HAPUS']);
    if (dup.isNotEmpty) return fail_('Email sudah digunakan user lain');

    final now = now_();
    final passwordHash = password.isNotEmpty ? hashPw_(password) : (existing?['password_hash'] as String? ?? '');

    if (existing != null) {
      await db.update(
        'users',
        {'email': email, 'name': name, 'role': role, 'status': status, 'phone': phone, 'address': address, 'password_hash': passwordHash, 'updated_at': now, 'sync_status': 0, 'last_modified': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert('users', {
        'id': id, 'email': email, 'name': name, 'password_hash': passwordHash,
        'role': role, 'status': status, 'phone': phone, 'address': address, 'created_at': now, 'updated_at': now,
        'sync_status': 0, 'last_modified': now,
      });
    }

    return ok_({'id': id, 'email': email, 'name': name, 'role': role, 'status': status, 'phone': phone, 'address': address}, 'User berhasil disimpan');
  }

  Future<Map<String, dynamic>> _userDelete(Map<String, dynamic> p) async {
    final me = await _assertAdmin();

    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID user wajib diisi');

    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return fail_('User tidak ditemukan');
    final row = rows.first;

    if (s_(row['email']).toLowerCase() == me.email.toLowerCase()) {
      return fail_('User yang sedang login tidak boleh menghapus dirinya sendiri');
    }

    await db.update('users', {'status': 'HAPUS', 'updated_at': now_(), 'sync_status': 0, 'last_modified': now_(), 'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    return ok_(null, 'User berhasil dihapus');
  }

  // ---------------------------------------------------------------------
  // PENGELUARAN
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _pengeluaranList(Map<String, dynamic> p) async {
    await _requireAuth();
    final db = await _db;

    final limit = int.tryParse(p['limit']?.toString() ?? '100') ?? 100;
    final offset = int.tryParse(p['offset']?.toString() ?? '0') ?? 0;
    final search = s_(p['search']).toLowerCase();

    String where = '';
    List<dynamic> whereArgs = [];
    if (search.isNotEmpty) {
      where = 'LOWER(keterangan) LIKE ?';
      whereArgs.add('%$search%');
    }

    final countRes = await db.query(
      'pengeluaran',
      columns: ['COUNT(*) as total'],
      where: where.isEmpty ? 'is_deleted = 0' : '$where AND is_deleted = 0',
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
    );
    final totalData = countRes.isNotEmpty ? (countRes.first['total'] as int? ?? 0) : 0;

    final rows = await db.query(
      'pengeluaran',
      where: where.isEmpty ? 'is_deleted = 0' : '$where AND is_deleted = 0',
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'tanggal DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );

    // Hitung Total Modal (HPP) dari Penjualan Hari Ini & Bulan Ini
    final today = todayYmd_();
    final thisMonth = today.substring(0, 7);

    const modalQuery = '''
      SELECT 
        SUM(IFNULL(d.modal_item, 0)) AS modalKeseluruhan,
        SUM(CASE WHEN t.tanggal LIKE ? THEN IFNULL(d.modal_item, 0) ELSE 0 END) AS modalHariIni,
        SUM(CASE WHEN t.tanggal LIKE ? THEN IFNULL(d.modal_item, 0) ELSE 0 END) AS modalBulanIni
      FROM transaksi t
      LEFT JOIN (
        SELECT td.transaksi_id, SUM(IFNULL(p.harga_beli, 0) * td.qty) AS modal_item
        FROM transaksi_detail td
        LEFT JOIN produk p ON td.produk_id = p.id
        WHERE td.is_deleted = 0
        GROUP BY td.transaksi_id
      ) d ON d.transaksi_id = t.id
      WHERE t.status = 'SELESAI' AND t.is_deleted = 0
    ''';
    
    final modalRows = await db.rawQuery(modalQuery, ['$today%', '$thisMonth%']);
    final mData = modalRows.isNotEmpty ? modalRows.first : {};

    double modalKeseluruhan = num_(mData['modalKeseluruhan']);
    double modalHariIni = num_(mData['modalHariIni']);
    double modalBulanIni = num_(mData['modalBulanIni']);

    return ok_({
      'data': rows,
      'total': totalData,
      'modalHariIni': modalHariIni,
      'modalBulanIni': modalBulanIni,
      'modalKeseluruhan': modalKeseluruhan,
    });
  }

  Future<Map<String, dynamic>> _pengeluaranSave(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final db = await _db;

    final tanggal = s_(p['tanggal']);
    final keterangan = s_(p['keterangan']);
    final jumlah = num_(p['jumlah']);

    if (tanggal.isEmpty) return fail_('Tanggal wajib diisi');
    if (keterangan.isEmpty) return fail_('Keterangan wajib diisi');
    if (jumlah <= 0) return fail_('Jumlah harus lebih dari 0');

    final id = uid_('PGL');
    await db.insert('pengeluaran', {
      'id': id,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'jumlah': jumlah,
      'kasir_name': me.name,
      'created_at': now_(),
      'sync_status': 0, 'last_modified': now_(),
    });

    await _logAudit(db, me.name, 'SAVE', 'Pengeluaran', id, 'Keterangan: $keterangan, Jumlah: $jumlah');
    return ok_(null, 'Pengeluaran berhasil disimpan');
  }

  Future<Map<String, dynamic>> _pengeluaranDelete(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final db = await _db;

    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID pengeluaran wajib diisi');

    await db.update('pengeluaran', {'is_deleted': 1, 'sync_status': 0, 'last_modified': now_()}, where: 'id = ?', whereArgs: [id]);
    await _logAudit(db, me.name, 'DELETE', 'Pengeluaran', id, 'Pengeluaran ID: $id dihapus');
    return ok_(null, 'Pengeluaran berhasil dihapus');
  }
  // ---------------------------------------------------------------------
  // SUPPLIER
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _supplierList(Map<String, dynamic> p) async {
    await _requireAuth();
    final db = await _db;

    final search = s_(p['search']).toLowerCase();
    String where = '';
    List<dynamic> whereArgs = [];

    if (search.isNotEmpty) {
      where = 'LOWER(nama_pt) LIKE ? OR LOWER(nomor) LIKE ?';
      whereArgs = ['%$search%', '%$search%'];
    }

    final rows = await db.query(
      'supplier',
      where: where.isEmpty ? 'is_deleted = 0' : '$where AND is_deleted = 0',
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    return ok_({'data': rows});
  }

  Future<Map<String, dynamic>> _supplierSave(Map<String, dynamic> p) async {
    await _requireAuth();
    final db = await _db;

    final id = s_(p['id']);
    final namaPt = s_(p['nama_pt']);
    final nomor = s_(p['nomor']);
    final alamat = s_(p['alamat']);

    if (namaPt.isEmpty) return fail_('Nama PT wajib diisi');

    if (id.isNotEmpty) {
      await db.update(
        'supplier',
        {
          'nama_pt': namaPt,
          'nomor': nomor,
          'alamat': alamat,
          'sync_status': 0, 'last_modified': now_(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return ok_(null, 'Supplier berhasil diupdate');
    }

    final newId = uid_('SUP');
    await db.insert('supplier', {
      'id': newId,
      'nama_pt': namaPt,
      'nomor': nomor,
      'alamat': alamat,
      'created_at': now_(),
      'sync_status': 0, 'last_modified': now_(),
    });

    return ok_(null, 'Supplier berhasil disimpan');
  }

  Future<Map<String, dynamic>> _supplierDelete(Map<String, dynamic> p) async {
    await _requireAuth();
    final db = await _db;

    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID supplier wajib diisi');

    await db.update('supplier', {'is_deleted': 1, 'sync_status': 0, 'last_modified': now_()}, where: 'id = ?', whereArgs: [id]);
    return ok_(null, 'Supplier berhasil dihapus');
  }
  Future<Map<String, dynamic>> _inventarisList(Map<String, dynamic> p) async {
    await _requireAuth();
    final db = await _db;
    final res = await db.query('inventaris', where: 'is_deleted = 0', orderBy: 'created_at DESC');
    return ok_({'data': res});
  }

  Future<Map<String, dynamic>> _inventarisSave(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final db = await _db;

    final id = s_(p['id']);
    final isNew = id.isEmpty;
    final finalId = isNew ? uid_('INV') : id;

    final namaBarang = s_(p['nama_barang']);
    final jumlah = int.tryParse(s_(p['jumlah'])) ?? 0;
    final kondisi = s_(p['kondisi']);
    final keterangan = s_(p['keterangan']);

    if (namaBarang.isEmpty) return fail_('Nama barang wajib diisi');
    if (jumlah < 0) return fail_('Jumlah tidak valid');
    if (kondisi.isEmpty) return fail_('Kondisi wajib diisi');

    final data = {
      'id': finalId,
      'nama_barang': namaBarang,
      'jumlah': jumlah,
      'kondisi': kondisi,
      'keterangan': keterangan,
      'status': 'AKTIF',
      'sync_status': 0,
      'last_modified': now_(),
    };

    await db.transaction((txn) async {
      if (isNew) {
        data['created_at'] = now_();
        data['updated_at'] = now_();
        await txn.insert('inventaris', data, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        data['updated_at'] = now_();
        await txn.update('inventaris', data, where: 'id = ?', whereArgs: [finalId]);
      }
    });

    await _logAudit(db, me.name, isNew ? 'CREATE' : 'UPDATE', 'Inventaris', id, 'Nama Barang: $namaBarang, Jumlah: $jumlah');
    return ok_(null, 'Inventaris berhasil disimpan');
  }

  Future<Map<String, dynamic>> _inventarisDelete(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    final db = await _db;

    final id = s_(p['id']);
    if (id.isEmpty) return fail_('ID inventaris wajib diisi');

    await db.update('inventaris', {'is_deleted': 1, 'sync_status': 0, 'last_modified': now_()}, where: 'id = ?', whereArgs: [id]);
    await _logAudit(db, me.name, 'DELETE', 'Inventaris', id, 'Inventaris ID: $id dihapus');
    return ok_(null, 'Inventaris berhasil dihapus');
  }

  Future<Map<String, dynamic>> _moneykuSummary(Map<String, dynamic> p) async {
    final me = await _requireAuth();
    if (me.role.toUpperCase() != 'ADMIN') return fail_('Akses ditolak');

    final tglMulai = s_(p['tglMulai']);
    final tglSelesai = s_(p['tglSelesai']);

    final db = await _db;
    
    // Build query to sum totals grouped by payment method
    String query = "SELECT metode, SUM(total) as total_uang FROM transaksi WHERE status != 'REFUND'";
    List<dynamic> args = [];

    if (tglMulai.isNotEmpty && tglSelesai.isNotEmpty) {
      query += " AND tanggal BETWEEN ? AND ?";
      args.addAll([tglMulai, tglSelesai]);
    } else if (tglMulai.isNotEmpty) {
      query += " AND tanggal >= ?";
      args.add(tglMulai);
    } else if (tglSelesai.isNotEmpty) {
      query += " AND tanggal <= ?";
      args.add(tglSelesai);
    }

    query += " GROUP BY metode";

    final rows = await db.rawQuery(query, args);
    
    double cash = 0;
    double qris = 0;
    double debit = 0;
    double transfer = 0;

    for (var r in rows) {
      final met = r['metode'].toString().toUpperCase();
      final tot = num_(r['total_uang']);
      if (met == 'CASH') {
        cash = tot;
      } else if (met == 'QRIS') {
        qris = tot;
      } else if (met == 'DEBIT') {
        debit = tot;
      } else if (met == 'TRANSFER') {
        transfer = tot;
      }
    }

    return ok_({
      'cash': cash,
      'qris': qris,
      'kredit': debit,
      'transfer': transfer,
    });
  }
}

class _Me {
  final String email;
  final String name;
  final String role;
  _Me({required this.email, required this.name, required this.role});
  Map<String, dynamic> toJson() => {'email': email, 'name': name, 'role': role};
}
