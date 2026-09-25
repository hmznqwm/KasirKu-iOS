/// Model-model data, dipetakan langsung dari struktur JSON yang dikembalikan
/// oleh api.php (lihat row_to_produk_, user_list_, transaksi_list_, dst).
library;

double _numFrom(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _strFrom(dynamic v) => (v ?? '').toString();

class Me {
  final String email;
  final String name;
  final String role;

  Me({required this.email, required this.name, required this.role});

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        email: _strFrom(j['email']),
        name: _strFrom(j['name']),
        role: _strFrom(j['role']),
      );

  Map<String, dynamic> toJson() => {'email': email, 'name': name, 'role': role};
}

class Produk {
  final String id;
  final String kode;
  final String nama;
  final String kategori;
  final String subKategori;
  final double hargaBeli;
  final double hargaJual;
  final double hargaJual2; // Harga varian ke-2 (Dingin / Tanpa Nasi)
  final double stok;
  final String satuan;
  final String status;
  final String foto;
  final String createdAt;
  final String updatedAt;

  Produk({
    required this.id,
    required this.kode,
    required this.nama,
    required this.kategori,
    this.subKategori = '',
    required this.hargaBeli,
    required this.hargaJual,
    this.hargaJual2 = 0,
    required this.stok,
    required this.satuan,
    required this.status,
    this.foto = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Produk.fromJson(Map<String, dynamic> j) => Produk(
        id: _strFrom(j['id']),
        kode: _strFrom(j['kode']),
        nama: _strFrom(j['nama']),
        kategori: _strFrom(j['kategori']),
        subKategori: _strFrom(j['subKategori'] ?? j['sub_kategori']),
        hargaBeli: _numFrom(j['hargaBeli'] ?? j['harga_beli']),
        hargaJual: _numFrom(j['hargaJual'] ?? j['harga_jual']),
        hargaJual2: _numFrom(j['hargaJual2'] ?? j['harga_jual_2']),
        stok: _numFrom(j['stok']),
        satuan: _strFrom(j['satuan']),
        status: _strFrom(j['status']),
        foto: _strFrom(j['foto']),
        createdAt: _strFrom(j['createdAt']),
        updatedAt: _strFrom(j['updatedAt']),
      );
}

class CartItem {
  final Produk produk;
  double qty;
  String varian; // 'Panas', 'Dingin', 'Pake Nasi', 'Tanpa Nasi', atau ''
  double? customHarga;

  CartItem({
    required this.produk,
    this.qty = 1,
    this.varian = '',
    this.customHarga,
  });

  String get cartKey => varian.isNotEmpty ? '${produk.id}__$varian' : produk.id;
  String get displayName => varian.isNotEmpty ? '${produk.nama} ($varian)' : produk.nama;
  double get hargaItem => customHarga ?? produk.hargaJual;
  double get subtotal => hargaItem * qty;
}

class TransaksiRow {
  final String id;
  final String invoice;
  final String tanggal;
  final String namaBarang;
  final double jumlah;
  final String kasirName;
  final double total;
  final double bayar;
  final double kembalian;
  final String metode;
  final String status;
  final String createdAt;

  TransaksiRow({
    required this.id,
    required this.invoice,
    required this.tanggal,
    required this.namaBarang,
    required this.jumlah,
    required this.kasirName,
    required this.total,
    required this.bayar,
    required this.kembalian,
    required this.metode,
    required this.status,
    required this.createdAt,
  });

  factory TransaksiRow.fromJson(Map<String, dynamic> j) => TransaksiRow(
        id: _strFrom(j['id']),
        invoice: _strFrom(j['invoice']),
        tanggal: _strFrom(j['tanggal']),
        namaBarang: _strFrom(j['namaBarang']),
        jumlah: _numFrom(j['jumlah']),
        kasirName: _strFrom(j['kasirName']),
        total: _numFrom(j['total']),
        bayar: _numFrom(j['bayar']),
        kembalian: _numFrom(j['kembalian']),
        metode: _strFrom(j['metode']),
        status: _strFrom(j['status']),
        createdAt: _strFrom(j['createdAt']),
      );
}

class CheckoutResult {
  final String invoice;
  final String tanggal;
  final String createdAt;
  final String kasirName;
  final double subtotal;
  final double diskon;
  final double total;
  final double bayar;
  final double kembalian;
  final String metode;
  final List<Map<String, dynamic>> items;

  CheckoutResult({
    required this.invoice,
    required this.tanggal,
    required this.createdAt,
    required this.kasirName,
    required this.subtotal,
    required this.diskon,
    required this.total,
    required this.bayar,
    required this.kembalian,
    required this.metode,
    required this.items,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> j) => CheckoutResult(
        invoice: _strFrom(j['invoice']),
        tanggal: _strFrom(j['tanggal']),
        createdAt: _strFrom(j['createdAt']),
        kasirName: _strFrom(j['kasirName']),
        subtotal: _numFrom(j['subtotal']),
        diskon: _numFrom(j['diskon']),
        total: _numFrom(j['total']),
        bayar: _numFrom(j['bayar']),
        kembalian: _numFrom(j['kembalian']),
        metode: _strFrom(j['metode']),
        items: List<Map<String, dynamic>>.from(j['items'] ?? []),
      );
}

class PengeluaranRow {
  final String id;
  final String tanggal;
  final String keterangan;
  final double jumlah;
  final String kasirName;
  final String createdAt;

  PengeluaranRow({
    required this.id,
    required this.tanggal,
    required this.keterangan,
    required this.jumlah,
    this.kasirName = '',
    required this.createdAt,
  });

  factory PengeluaranRow.fromJson(Map<String, dynamic> j) => PengeluaranRow(
        id: _strFrom(j['id']),
        tanggal: _strFrom(j['tanggal']),
        keterangan: _strFrom(j['keterangan']),
        jumlah: _numFrom(j['jumlah']),
        kasirName: _strFrom(j['kasir_name']),
        createdAt: _strFrom(j['created_at']),
      );
}

class SupplierRow {
  final String id;
  final String namaPt;
  final String nomor;
  final String alamat;
  final String createdAt;

  SupplierRow({
    required this.id,
    required this.namaPt,
    required this.nomor,
    required this.alamat,
    required this.createdAt,
  });

  factory SupplierRow.fromJson(Map<String, dynamic> j) => SupplierRow(
        id: _strFrom(j['id']),
        namaPt: _strFrom(j['nama_pt']),
        nomor: _strFrom(j['nomor']),
        alamat: _strFrom(j['alamat']),
        createdAt: _strFrom(j['created_at']),
      );
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String status;
  final String phone;
  final String address;
  final String createdAt;
  final String updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.phone,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _strFrom(j['id']),
        email: _strFrom(j['email']),
        name: _strFrom(j['name']),
        role: _strFrom(j['role']),
        status: _strFrom(j['status']),
        phone: _strFrom(j['phone']),
        address: _strFrom(j['address']),
        createdAt: _strFrom(j['createdAt']),
        updatedAt: _strFrom(j['updatedAt']),
      );
}

class DashboardSummary {
  final double transHariIni;
  final double transKemarin;
  final double transBulanIni;
  final double profitHariIni;
  final double totalTrans;
  final double totalProfit;
  final int totalProdukAktif;

  DashboardSummary({
    required this.transHariIni,
    required this.transKemarin,
    required this.transBulanIni,
    required this.profitHariIni,
    required this.totalTrans,
    required this.totalProfit,
    required this.totalProdukAktif,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        transHariIni: _numFrom(j['transHariIni']),
        transKemarin: _numFrom(j['transKemarin']),
        transBulanIni: _numFrom(j['transBulanIni']),
        profitHariIni: _numFrom(j['profitHariIni']),
        totalTrans: _numFrom(j['totalTrans']),
        totalProfit: _numFrom(j['totalProfit']),
        totalProdukAktif: (j['totalProdukAktif'] is num) ? (j['totalProdukAktif'] as num).toInt() : 0,
      );
}

class InventarisRow {
  final String id;
  final String namaBarang;
  final int jumlah;
  final String kondisi;
  final String keterangan;
  final String status;
  final String createdAt;

  InventarisRow({
    required this.id,
    required this.namaBarang,
    required this.jumlah,
    required this.kondisi,
    required this.keterangan,
    required this.status,
    required this.createdAt,
  });

  factory InventarisRow.fromJson(Map<String, dynamic> json) {
    return InventarisRow(
      id: json['id']?.toString() ?? '',
      namaBarang: json['nama_barang']?.toString() ?? '',
      jumlah: int.tryParse(json['jumlah']?.toString() ?? '0') ?? 0,
      kondisi: json['kondisi']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
