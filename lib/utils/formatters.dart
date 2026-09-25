import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

final _rupiahFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _numFmt = NumberFormat.decimalPattern('id_ID');

String rupiah(num value) => _rupiahFmt.format(value);

String angka(num value) => _numFmt.format(value);

String tanggalIndo(String raw) {
  if (raw.isEmpty) return '-';
  try {
    DateTime dt;
    if (raw.contains('T') || raw.contains('-')) {
      dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
    } else {
      dt = DateTime.parse(raw);
    }
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
  } catch (_) {
    return raw;
  }
}

String tanggalPendek(String raw) {
  if (raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
    return DateFormat('d MMM yyyy', 'id_ID').format(dt);
  } catch (_) {
    return raw;
  }
}

String tanggalBulan(String raw) {
  if (raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
    return DateFormat('d MMM', 'id_ID').format(dt);
  } catch (_) {
    return raw;
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final value = double.tryParse(cleanText) ?? 0.0;
    final formatter = NumberFormat.decimalPattern('id_ID');
    final newText = formatter.format(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}