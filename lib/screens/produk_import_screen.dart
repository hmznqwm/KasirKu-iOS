import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// Satu baris hasil parsing template CSV, sebelum dikirim ke
/// `produk.import`. Menyimpan juga status validasi supaya bisa
/// ditampilkan & dipilih/dilewati di layar pratinjau.
class _ImportRow {
  final int rowNumber;
  String kode;
  String nama;
  String kategori;
  String subKategori;
  double hargaBeli;
  double hargaJual;
  String satuan;
  bool selected;
  bool isDuplicateKode;

  _ImportRow({
    required this.rowNumber,
    required this.kode,
    required this.nama,
    required this.kategori,
    required this.subKategori,
    required this.hargaBeli,
    required this.hargaJual,
    required this.satuan,
    required this.selected,
    this.isDuplicateKode = false,
  });

  /// Satu-satunya syarat wajib mengikuti backend (`produk.import`):
  /// baris tanpa nama akan dilewati saat import.
  bool get isValid => nama.trim().isNotEmpty;

  /// Bukan invalid, tapi patut diberi tahu ke pengguna (harga jual 0
  /// tetap akan tersimpan, sama seperti lewat form Tambah Produk yang
  /// mewajibkan > 0, jadi baris begini kemungkinan perlu dicek ulang).
  /// Kode yang muncul lebih dari sekali di file juga diberi tahu, supaya
  /// pengguna tidak tanpa sadar membuat produk kembar.
  bool get hasWarning => isValid && (hargaJual <= 0 || isDuplicateKode);

  Map<String, dynamic> toPayload() => {
        'kode': kode,
        'nama': nama,
        'kategori': kategori,
        'subKategori': subKategori,
        'hargaBeli': hargaBeli,
        'hargaJual': hargaJual,
        'stok': 0,
        'satuan': satuan,
      };
}

const List<String> _templateHeaders = [
  'kode',
  'nama',
  'kategori',
  'sub_kategori',
  'hargaBeli',
  'hargaJual',
  'satuan',
];

const List<List<String>> _templateSampleRows = [
  ['BRG-001', 'Contoh Produk A', 'Makanan', 'Snack', '8000', '10000', 'PCS'],
  ['BRG-002', 'Contoh Produk B', 'Minuman', 'Dingin', '4000', '6000', 'BOTOL'],
];

class ProdukImportScreen extends StatefulWidget {
  const ProdukImportScreen({super.key});

  @override
  State<ProdukImportScreen> createState() => _ProdukImportScreenState();
}

class _ProdukImportScreenState extends State<ProdukImportScreen> {
  final _api = ApiService.instance;

  String? _fileName;
  List<_ImportRow> _rows = [];
  bool _parsing = false;
  bool _importing = false;
  String? _parseError;

  int get _validSelectedCount => _rows.where((r) => r.isValid && r.selected).length;
  int get _invalidCount => _rows.where((r) => !r.isValid).length;

  // ---------------------------------------------------------------------
  // TEMPLATE
  // ---------------------------------------------------------------------

  void _showDownloadTemplateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Pilih Format Template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined, color: Colors.green),
                title: const Text('Template Excel (.xlsx)'),
                subtitle: const Text('Direkomendasikan. Lebih rapi dan mudah diedit.'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadTemplateExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.blue),
                title: const Text('Template CSV (.csv)'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadTemplateCsv();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadTemplateExcel() async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Sheet1'];
      excel.setDefaultSheet('Sheet1');

      sheet.appendRow(_templateHeaders.map((e) => TextCellValue(e)).toList());
      for (final row in _templateSampleRows) {
        sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
      }

      var fileBytes = excel.encode();
      if (fileBytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/template_produk_kasirku.xlsx');
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'template_produk_kasirku.xlsx')],
          subject: 'Template Import Produk KasirKu (Excel)',
          text: 'Isi kolom pada template Excel ini lalu impor kembali lewat KasirKu > Produk > Import Massal.',
        );
      }
    } catch (e) {
      if (mounted) showToast(context, 'Gagal membuat template Excel: $e', isError: true);
    }
  }

  Future<void> _downloadTemplateCsv() async {
    try {
      final csv = const ListToCsvConverter().convert([
        _templateHeaders,
        ..._templateSampleRows,
      ]);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/template_produk_kasirku.csv');
      // Sertakan BOM UTF-8 supaya kalau file ini dibuka & disimpan ulang
      // lewat Excel, karakter khusus pada nama produk (misal "é", "—")
      // tetap konsisten terbaca UTF-8 -- sinkron dengan sisi import yang
      // sudah membuang BOM kalau ada.
      await file.writeAsString('\ufeff$csv');

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: 'template_produk_kasirku.csv')],
        subject: 'Template Import Produk KasirKu',
        text: 'Isi kolom pada template ini lalu impor kembali lewat KasirKu > Produk > Import Massal.',
      );
    } catch (e) {
      if (mounted) showToast(context, 'Gagal membuat template: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // PILIH & PARSE FILE
  // ---------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      
      setState(() {
        _fileName = picked.name;
        _parsing = true;
        _parseError = null;
        _rows = [];
      });

      if (picked.name.toLowerCase().endsWith('.xlsx')) {
        List<int> fileBytes = [];
        if (bytes != null && bytes.isNotEmpty) {
          fileBytes = bytes;
        } else if (picked.path != null) {
          fileBytes = await File(picked.path!).readAsBytes();
        }

        if (fileBytes.isNotEmpty) {
          try {
            _parseExcel(fileBytes);
          } catch (e) {
            // Fallback jika file ternyata teks CSV (misal disave sebagai CSV bertipe .xlsx)
            if (picked.path != null) {
              final content = await File(picked.path!).readAsString();
              _parseCsv(content);
            } else {
              rethrow;
            }
          }
        } else {
          throw Exception('File Excel kosong atau tidak dapat dibaca');
        }
      } else {
        String content = '';
        if (bytes != null && bytes.isNotEmpty) {
          content = utf8.decode(bytes, allowMalformed: true);
        } else if (picked.path != null) {
          content = await File(picked.path!).readAsString();
        }

        if (content.isNotEmpty) {
          _parseCsv(content);
        } else {
          throw Exception('File CSV kosong atau tidak dapat dibaca');
        }
      }
    } catch (e) {
      setState(() {
        _parsing = false;
        _parseError = 'Gagal membaca file: $e';
      });
    }
  }

  /// Ekstraksi aman teks dari nilai sel Excel (termasuk TextCellValue, IntCellValue, dll).
  String _cellToString(dynamic val) {
    if (val == null) return '';
    if (val is TextCellValue) return val.value.toString();
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    if (val is BoolCellValue) return val.value.toString();
    if (val is FormulaCellValue) return val.formula;
    return val.toString();
  }

  /// Normalisasi string header untuk pencarian kolom yang lebih fleksibel.
  String _normalizeHeader(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Mencari indeks kolom berdasarkan urutan prioritas alias kandidat dan kata kunci.
  int _findCol(List<String> header, List<String> candidates, List<String> keywords) {
    // 1. Prioritaskan pencarian persis dari kandidat teratas
    for (final c in candidates) {
      final cNorm = _normalizeHeader(c);
      for (var i = 0; i < header.length; i++) {
        final norm = _normalizeHeader(header[i]);
        if (norm == cNorm) return i;
      }
    }
    // 2. Fallback pencarian kata kunci substring
    for (final kw in keywords) {
      final kwNorm = _normalizeHeader(kw);
      for (var i = 0; i < header.length; i++) {
        final norm = _normalizeHeader(header[i]);
        if (norm.contains(kwNorm)) return i;
      }
    }
    return -1;
  }

  /// Mencari indeks baris judul (header) pada file.
  int _findHeaderRow(List<List<dynamic>> table) {
    for (var i = 0; i < table.length && i < 15; i++) {
      final row = table[i];
      for (final cell in row) {
        if (cell == null) continue;
        final norm = _normalizeHeader(_cellToString(cell));
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

  /// Menebak pemisah kolom CSV dari baris-baris awal file.
  String _detectDelimiter(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
    if (lines.isEmpty) return ',';
    
    const candidates = [',', ';', '\t', '|'];
    var best = ',';
    var bestCount = 0;
    for (final d in candidates) {
      var total = 0;
      for (final l in lines) {
        total += l.split(d).length - 1;
      }
      if (total > bestCount) {
        bestCount = total;
        best = d;
      }
    }
    return best;
  }

  /// Mengubah teks angka dari CSV / Excel (yang bisa dalam berbagai format
  /// penulisan) menjadi double yang presisi. Menangani:
  /// - Format ribuan Indonesia: "10.000" / "1.000.000" -> 10000 / 1000000
  /// - Format desimal koma ala Indonesia: "8.000,50" -> 8000.5
  /// - Format ribuan koma (US): "10,000" -> 10000
  /// - Format desimal titik: "8000.50" -> 8000.5
  /// - Simbol mata uang / spasi: "Rp 10.000" -> 10000
  double _parseAmount(dynamic rawInput) {
    if (rawInput == null) return 0;
    if (rawInput is num) return rawInput.toDouble();
    var s = _cellToString(rawInput).trim();
    if (s.isEmpty) return 0;

    final negative = s.startsWith('-');
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return 0;

    final hasDot = s.contains('.');
    final hasComma = s.contains(',');

    String normalized = s;

    if (hasDot && hasComma) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastDot < lastComma) {
        // 10.000,50 -> dot is thousand, comma is decimal
        normalized = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // 10,000.50 -> comma is thousand, dot is decimal
        normalized = s.replaceAll(',', '');
      }
    } else if (hasDot) {
      final dotCount = '.'.allMatches(s).length;
      if (dotCount > 1) {
        // 1.000.000 -> thousands separators
        normalized = s.replaceAll('.', '');
      } else {
        final lastDot = s.indexOf('.');
        final digitsAfter = s.length - lastDot - 1;
        if (digitsAfter == 3) {
          // 10.000 or 250.000 -> thousand separator
          normalized = s.replaceAll('.', '');
        } else {
          // 10.5 or 10.50 -> decimal point
          normalized = s;
        }
      }
    } else if (hasComma) {
      final commaCount = ','.allMatches(s).length;
      if (commaCount > 1) {
        // 1,000,000 -> thousands separators
        normalized = s.replaceAll(',', '');
      } else {
        final lastComma = s.indexOf(',');
        final digitsAfter = s.length - lastComma - 1;
        if (digitsAfter == 3) {
          // 10,000 -> thousand separator
          normalized = s.replaceAll(',', '');
        } else {
          // 10,50 -> decimal point
          normalized = s.replaceAll(',', '.');
        }
      }
    }

    final value = double.tryParse(normalized) ?? 0;
    return negative ? -value : value;
  }

  void _parseExcel(List<int> bytes) {
    try {
      var excel = Excel.decodeBytes(bytes);
      
      // Cari sheet yang tidak kosong dan memiliki baris header yang valid
      int headerRowIdx = 0;
      List<List<Data?>>? table;

      for (final sheetName in excel.tables.keys) {
        final rows = excel.tables[sheetName]?.rows;
        if (rows != null && rows.isNotEmpty) {
          final dynTable = rows.map((r) => r.map((c) => c?.value).toList()).toList();
          final hIdx = _findHeaderRow(dynTable);
          if (hIdx != -1) {
            headerRowIdx = hIdx;
            table = rows;
            break;
          }
        }
      }

      if (table == null || table.isEmpty) {
        // Coba jadikan sheet pertama sebagai fallback jika tidak menemukan kata kunci
        final firstKey = excel.tables.keys.firstOrNull;
        if (firstKey != null) {
          table = excel.tables[firstKey]?.rows;
          headerRowIdx = 0;
        }
      }

      if (table == null || table.isEmpty) {
        setState(() {
          _parsing = false;
          _parseError = 'File Excel kosong atau formatnya tidak dikenali.';
        });
        return;
      }

      final headerRow = table[headerRowIdx];
      final header = headerRow.map((e) => _cellToString(e?.value).trim()).toList();

      final iKode = _findCol(
        header,
        ['kode', 'kode_barang', 'kode barang', 'sku', 'kodeproduk', 'kode produk', 'id'],
        ['kode', 'sku'],
      );
      final iNama = _findCol(
        header,
        ['nama', 'nama_barang', 'nama barang', 'nama produk', 'namaproduk', 'namabarang', 'produk', 'item', 'description'],
        ['nama', 'produk', 'item'],
      );
      final iKategori = _findCol(
        header,
        ['kategori', 'kategori produk', 'kategori_produk', 'kelompok', 'group', 'category'],
        ['kategori', 'category', 'kelompok'],
      );
      final iSubKategori = _findCol(
        header,
        ['sub_kategori', 'sub kategori', 'subkategori', 'sub category', 'subcategory'],
        ['sub'],
      );
      final iHargaBeli = _findCol(
        header,
        ['hargabeli', 'harga_beli', 'harga beli', 'harga modal', 'harga_modal', 'hpp', 'modal', 'cost', 'buy price'],
        ['hargabeli', 'beli', 'modal', 'hpp', 'cost'],
      );
      final iHargaJual = _findCol(
        header,
        ['hargajual', 'harga_jual', 'harga jual', 'harga', 'harga_satuan', 'harga satuan', 'price', 'sell price'],
        ['hargajual', 'jual', 'harga', 'price'],
      );
      final iSatuan = _findCol(
        header,
        ['satuan', 'unit', 'uom', 'kemasan', 'pack'],
        ['satuan', 'unit', 'uom'],
      );

      if (iNama == -1) {
        setState(() {
          _parsing = false;
          _parseError = 'Kolom "nama" tidak ditemukan pada baris judul file Excel. '
              'Pastikan ada kolom dengan judul "nama", "nama barang", atau "nama produk".';
        });
        return;
      }

      dynamic cellRaw(List<Data?> row, int idx) {
        if (idx == -1 || idx >= row.length) return null;
        return row[idx]?.value;
      }

      String cellStr(List<Data?> row, int idx) {
        final raw = cellRaw(row, idx);
        return _cellToString(raw).trim();
      }

      final parsed = <_ImportRow>[];
      final seenKode = <String>{};
      for (var i = headerRowIdx + 1; i < table.length; i++) {
        final row = table[i];
        if (row.isEmpty) continue; // baris kosong
        final nama = cellStr(row, iNama);
        if (row.length <= 1 && nama.isEmpty) continue;
        
        final kode = cellStr(row, iKode);
        final isDup = kode.isNotEmpty && !seenKode.add(kode.toUpperCase());
        
        final katInduk = iKategori == -1 || cellStr(row, iKategori).isEmpty ? 'Lainnya' : cellStr(row, iKategori);
        final katSub = iSubKategori == -1 ? '' : cellStr(row, iSubKategori);

        parsed.add(_ImportRow(
          rowNumber: i + 1,
          kode: kode,
          nama: nama,
          kategori: katInduk,
          subKategori: katSub,
          hargaBeli: _parseAmount(cellRaw(row, iHargaBeli)),
          hargaJual: _parseAmount(cellRaw(row, iHargaJual)),
          satuan: iSatuan == -1 || cellStr(row, iSatuan).isEmpty ? 'PCS' : cellStr(row, iSatuan).toUpperCase(),
          selected: nama.trim().isNotEmpty,
          isDuplicateKode: isDup,
        ));
      }

      setState(() {
        _parsing = false;
        _rows = parsed;
        if (parsed.isEmpty) {
          _parseError = 'Tidak ada baris data yang ditemukan di dalam file.';
        } else if (parsed.every((r) => !r.isValid)) {
          _parseError = 'Semua baris gagal terbaca (kolom "nama" kosong di semua baris).';
        }
      });
    } catch (e) {
      setState(() {
        _parsing = false;
        _parseError = 'Format Excel tidak valid: $e';
      });
    }
  }

  void _parseCsv(String rawContent) {
    try {
      final content = rawContent.startsWith('\ufeff') ? rawContent.substring(1) : rawContent;
      final normalizedContent = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final delimiter = _detectDelimiter(normalizedContent);
      
      List<List<dynamic>> table;
      try {
        table = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
            .convert(normalizedContent, fieldDelimiter: delimiter);
      } catch (_) {
        table = normalizedContent
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .map((l) => l.split(delimiter))
            .toList();
      }

      if (table.isEmpty) {
        setState(() {
          _parsing = false;
          _parseError = 'File kosong atau formatnya tidak dikenali.';
        });
        return;
      }

      var headerRowIdx = _findHeaderRow(table);
      if (headerRowIdx == -1) headerRowIdx = 0;

      final headerRow = table[headerRowIdx];
      final header = headerRow.map((e) => _cellToString(e).trim().replaceAll('"', '')).toList();

      final iKode = _findCol(
        header,
        ['kode', 'kode_barang', 'kode barang', 'sku', 'kodeproduk', 'kode produk', 'id'],
        ['kode', 'sku'],
      );
      final iNama = _findCol(
        header,
        ['nama', 'nama_barang', 'nama barang', 'nama produk', 'namaproduk', 'namabarang', 'produk', 'item', 'description'],
        ['nama', 'produk', 'item'],
      );
      final iKategori = _findCol(
        header,
        ['kategori', 'kategori produk', 'kategori_produk', 'kelompok', 'group', 'category'],
        ['kategori', 'category', 'kelompok'],
      );
      final iSubKategori = _findCol(
        header,
        ['sub_kategori', 'sub kategori', 'subkategori', 'sub category', 'subcategory'],
        ['sub'],
      );
      final iHargaBeli = _findCol(
        header,
        ['hargabeli', 'harga_beli', 'harga beli', 'harga modal', 'harga_modal', 'hpp', 'modal', 'cost', 'buy price'],
        ['hargabeli', 'beli', 'modal', 'hpp', 'cost'],
      );
      final iHargaJual = _findCol(
        header,
        ['hargajual', 'harga_jual', 'harga jual', 'harga', 'harga_satuan', 'harga satuan', 'price', 'sell price'],
        ['hargajual', 'jual', 'harga', 'price'],
      );
      final iSatuan = _findCol(
        header,
        ['satuan', 'unit', 'uom', 'kemasan', 'pack'],
        ['satuan', 'unit', 'uom'],
      );

      if (iNama == -1) {
        setState(() {
          _parsing = false;
          _parseError = 'Kolom "nama" tidak ditemukan pada baris judul file CSV.';
        });
        return;
      }

      String cell(List<dynamic> row, int idx) =>
          idx == -1 || idx >= row.length ? '' : _cellToString(row[idx]).trim();

      final parsed = <_ImportRow>[];
      final seenKode = <String>{};
      for (var i = headerRowIdx + 1; i < table.length; i++) {
        final row = table[i];
        if (row.length <= 1 && cell(row, 0).isEmpty) continue; // baris kosong
        final nama = cell(row, iNama);
        final kode = cell(row, iKode);
        final isDup = kode.isNotEmpty && !seenKode.add(kode.toUpperCase());
        
        final katInduk = iKategori == -1 || cell(row, iKategori).isEmpty ? 'Lainnya' : cell(row, iKategori);
        final katSub = iSubKategori == -1 ? '' : cell(row, iSubKategori);

        parsed.add(_ImportRow(
          rowNumber: i + 1,
          kode: kode,
          nama: nama,
          kategori: katInduk,
          subKategori: katSub,
          hargaBeli: _parseAmount(iHargaBeli == -1 || iHargaBeli >= row.length ? null : row[iHargaBeli]),
          hargaJual: _parseAmount(iHargaJual == -1 || iHargaJual >= row.length ? null : row[iHargaJual]),
          satuan: iSatuan == -1 || cell(row, iSatuan).isEmpty ? 'PCS' : cell(row, iSatuan).toUpperCase(),
          selected: nama.trim().isNotEmpty,
          isDuplicateKode: isDup,
        ));
      }

      setState(() {
        _parsing = false;
        _rows = parsed;
        if (parsed.isEmpty) {
          _parseError = 'Tidak ada baris data yang ditemukan di dalam file.';
        } else if (parsed.every((r) => !r.isValid)) {
          _parseError = 'Semua baris gagal terbaca (kolom "nama" kosong di semua baris).';
        }
      });
    } catch (e) {
      setState(() {
        _parsing = false;
        _parseError = 'Format CSV tidak valid: $e';
      });
    }
  }

  // ---------------------------------------------------------------------
  // IMPORT
  // ---------------------------------------------------------------------

  Future<void> _import() async {
    final isAdmin = context.read<AuthProvider>().me?.isAdmin ?? false;
    if (!isAdmin) {
      showToast(context, 'Akses ditolak: Kasir tidak diizinkan mengimpor produk', isError: true);
      return;
    }
    final payload = _rows.where((r) => r.isValid && r.selected).map((r) => r.toPayload()).toList();
    if (payload.isEmpty) {
      showToast(context, 'Tidak ada produk terpilih untuk diimpor', isError: true);
      return;
    }

    final ok = await confirmDialog(
      context,
      title: 'Import Produk',
      message: 'Impor ${payload.length} produk ke daftar produk sekarang?',
    );
    if (!ok) return;

    setState(() => _importing = true);
    try {
      await _api.call('produk.import', {'data': payload});
      if (mounted) {
        context.read<EventProvider>().refreshProduk();
        showToast(context, '${payload.length} produk berhasil diimpor');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Produk Massal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Langkah 1: Siapkan Template', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unduh template CSV atau Excel, isi data produk (kode, nama, kategori, hargaBeli, '
                  'hargaJual, satuan), lalu simpan filenya di HP Anda.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showDownloadTemplateOptions,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Unduh / Bagikan Template'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Langkah 2: Pilih File Terisi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih file CSV atau Excel (.xlsx) template yang sudah Anda isi untuk dipratinjau sebelum diimpor.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _parsing ? null : _pickFile,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(_fileName == null ? 'Pilih File (Excel / CSV)' : 'Ganti File (${_fileName!})'),
                ),
              ],
            ),
          ),
          if (_parsing) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_parseError != null) ...[
            const SizedBox(height: 14),
            AlertBanner.error(_parseError!),
          ],
          if (!_parsing && _rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Langkah 3: Pratinjau (${_rows.length} baris)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final r in _rows) {
                      if (r.isValid) r.selected = true;
                    }
                  }),
                  child: const Text('Pilih Semua'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_invalidCount > 0)
              AlertBanner.warning('$_invalidCount baris dilewati karena kolom "nama" kosong.'),
            const SizedBox(height: 6),
            ..._rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: r.selected,
                          onChanged: r.isValid ? (v) => setState(() => r.selected = v ?? false) : null,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.nama.isEmpty ? '(Baris ${r.rowNumber}: nama kosong)' : r.nama,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!r.isValid)
                                    const StatusPill(text: 'Dilewati', bg: AppColors.stockOutBg, fg: AppColors.stockOutText)
                                  else if (r.isDuplicateKode)
                                    const StatusPill(text: 'Kode Ganda', bg: AppColors.stockLowBg, fg: AppColors.stockLowText)
                                  else if (r.hasWarning)
                                    const StatusPill(text: 'Cek Harga', bg: AppColors.stockLowBg, fg: AppColors.stockLowText)
                                  else
                                    const StatusPill(text: 'Siap', bg: AppColors.stockOkBg, fg: AppColors.stockOkText),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${r.kode.isEmpty ? '(otomatis)' : r.kode} • ${r.kategori} • ${r.satuan}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Beli: ${rupiah(r.hargaBeli)}   Jual: ${rupiah(r.hargaJual)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
      bottomNavigationBar: (!_parsing && _rows.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: FilledButton(
                  onPressed: (_importing || _validSelectedCount == 0) ? null : _import,
                  child: _importing
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Import $_validSelectedCount Produk'),
                ),
              ),
            )
          : null,
    );
  }
}
