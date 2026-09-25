import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Kumpulan fungsi bantu, port 1:1 dari helpers.php, dipakai oleh
/// ApiService versi offline (menggantikan pemanggilan ke server PHP).

String s_(dynamic v) => (v ?? '').toString().trim();

double num_(dynamic v) {
  final clean = (v ?? '0').toString().replaceAll(RegExp(r'[^\d.\-]'), '');
  return double.tryParse(clean) ?? 0;
}

String pad2(int n) => n.toString().padLeft(2, '0');

String now_() {
  final d = DateTime.now();
  return '${d.year}-${pad2(d.month)}-${pad2(d.day)} ${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}';
}

String todayYmd_() {
  final d = DateTime.now();
  return '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
}

final _rnd = Random.secure();

String uid_(String prefix) {
  final bytes = List<int>.generate(4, (_) => _rnd.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$prefix-${hex.toUpperCase()}';
}

String makeInvoice_() {
  final d = DateTime.now();
  return 'INV-${d.year}${pad2(d.month)}${pad2(d.day)}-${pad2(d.hour)}${pad2(d.minute)}${pad2(d.second)}';
}

String hashPw_(String text) => sha256.convert(utf8.encode(text)).toString();

List<String> uniqueSort_(Iterable<dynamic> arr) {
  final map = <String, String>{};
  for (final v in arr) {
    final val = s_(v);
    if (val.isNotEmpty) map[val.toUpperCase()] = val;
  }
  final keys = map.keys.toList()..sort();
  return keys.map((k) => map[k]!).toList();
}

String normalizeDateYmd_(dynamic value) {
  if (value == null) return '';
  final text = s_(value);
  if (text.isEmpty) return '';

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (isoMatch != null) {
    return '${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}';
  }

  final dmyMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(text);
  if (dmyMatch != null) {
    final d = dmyMatch[1]!.padLeft(2, '0');
    final m = dmyMatch[2]!.padLeft(2, '0');
    final y = dmyMatch[3]!;
    return '$y-$m-$d';
  }

  final ts = DateTime.tryParse(text);
  if (ts != null) {
    return '${ts.year}-${pad2(ts.month)}-${pad2(ts.day)}';
  }
  return text;
}

const _bulan = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const _bulanSingkat = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String namaBulanId_(int n) => (n >= 1 && n <= 12) ? _bulan[n] : '';
String namaBulanSingkatId_(int n) => (n >= 1 && n <= 12) ? _bulanSingkat[n] : '';

/// Exception yang pesannya (message) langsung ditampilkan ke user,
/// sama seperti `fail_()` / `throw new Exception(...)` di backend PHP lama.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
