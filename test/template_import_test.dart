import 'package:flutter_test/flutter_test.dart';

String _normalizeHeader(String s) {
  return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

int _findCol(List<String> header, List<String> candidates, List<String> keywords) {
  // 1. Search in order of candidate priority
  for (final c in candidates) {
    final cNorm = _normalizeHeader(c);
    for (var i = 0; i < header.length; i++) {
      final norm = _normalizeHeader(header[i]);
      if (norm == cNorm) return i;
    }
  }
  // 2. Search in order of keyword priority
  for (final kw in keywords) {
    final kwNorm = _normalizeHeader(kw);
    for (var i = 0; i < header.length; i++) {
      final norm = _normalizeHeader(header[i]);
      if (norm.contains(kwNorm)) return i;
    }
  }
  return -1;
}

int _findHeaderRow(List<List<dynamic>> table) {
  for (var i = 0; i < table.length && i < 15; i++) {
    final row = table[i];
    for (final cell in row) {
      if (cell == null) continue;
      final norm = _normalizeHeader(cell.toString());
      if (norm == 'nama' ||
          norm == 'namaproduk' ||
          norm == 'namabarang' ||
          norm == 'produk' ||
          norm == 'item' ||
          norm.contains('nama') ||
          norm.contains('produk')) {
        return i;
      }
    }
  }
  return -1;
}

void main() {
  test('AI-generated header detection with variations', () {
    final aiHeaders1 = ['NO', 'SKU', 'NAMA PRODUK', 'KELOMPOK', 'HARGA MODAL', 'HARGA JUAL', 'SATUAN'];
    final aiHeaders2 = ['No.', 'Kode_Barang', 'Nama_Barang', 'Kategori', 'HPP', 'Harga', 'Unit'];
    final aiHeaders3 = ['ID', 'Kode', 'Item', 'Category', 'Cost', 'Price', 'UOM'];

    final candidatesNama = ['nama', 'nama_barang', 'nama barang', 'nama produk', 'namaproduk', 'namabarang', 'produk', 'item', 'description'];
    final keywordsNama = ['nama', 'produk', 'item'];

    final candidatesKode = ['kode', 'kode_barang', 'kode barang', 'sku', 'kodeproduk', 'kode produk', 'id'];
    final keywordsKode = ['kode', 'sku'];

    expect(_findCol(aiHeaders1, candidatesNama, keywordsNama), equals(2));
    expect(_findCol(aiHeaders1, candidatesKode, keywordsKode), equals(1));

    expect(_findCol(aiHeaders2, candidatesNama, keywordsNama), equals(2));
    expect(_findCol(aiHeaders2, candidatesKode, keywordsKode), equals(1));

    expect(_findCol(aiHeaders3, candidatesNama, keywordsNama), equals(2));
    expect(_findCol(aiHeaders3, candidatesKode, keywordsKode), equals(1));
  });

  test('Find header row in multi-row table with instruction text at top', () {
    final table = [
      ['DATA HARGA KASIRKU'],
      ['PETUNJUK: JANGAN UBAH SUSUNAN KOLOM'],
      [null, null, null],
      ['No', 'Kode Barang', 'Nama Barang', 'Kategori', 'Harga Modal', 'Harga Jual', 'Satuan'],
      ['1', 'BRG-001', 'Kopi Hitam', 'Minuman', '3000', '5000', 'CUP']
    ];

    final headerIdx = _findHeaderRow(table);
    expect(headerIdx, equals(3));
  });
}
