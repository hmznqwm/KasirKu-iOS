import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// Ukuran kertas thermal yang didukung. Lebar dalam jumlah karakter huruf
/// monospace kira-kira: 58mm -> 32 kolom, 80mm -> 48 kolom (font normal).
enum PaperSize { mm58, mm80 }

extension PaperSizeX on PaperSize {
  int get columns => this == PaperSize.mm58 ? 32 : 48;
  String get label => this == PaperSize.mm58 ? '58mm' : '80mm';
}

/// Data profil toko yang dicetak di kop struk. Silakan ganti nilai default
/// di bawah ini sesuai identitas toko Anda, atau nanti dihubungkan ke layar
/// pengaturan toko bila sudah tersedia.
class StoreProfile {
  static const String name = 'KASIRKU';
  static const String address = 'Jl. Contoh Alamat No. 1, Kota Anda';
  static const String phone = '0812-0000-0000';
  static const String footerNote = 'Terima kasih telah berbelanja!';
}

/// Service untuk membangun teks struk dan mengirimkannya ke aplikasi RawBT
/// (RawBT ESC/POS Printer Driver) lewat skema intent URL standar RawBT:
///
///   rawbt:base64,<data terenkode base64>
///
/// RawBT akan menangkap intent tersebut, mendekode base64-nya, dan mengirim
/// isinya sebagai teks polos ke printer thermal Bluetooth/USB/WiFi yang
/// sudah dikonfigurasi di aplikasi RawBT. Tidak perlu koneksi Bluetooth
/// langsung dari sisi aplikasi ini — semua ditangani oleh RawBT.
class PrintService {
  PrintService._();

  static const String _rawBtPackage = 'ru.a402d.rawbtprinter';
  static const String _rawBtPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=$_rawBtPackage';

  /// Bangun teks struk polos (bukan HTML/PDF) yang rapi untuk printer
  /// thermal, mengikuti lebar kolom kertas yang dipilih (32 kolom untuk
  /// 58mm, 48 kolom untuk 80mm). Menggunakan padding spasi manual karena
  /// printer ESC/POS teks polos tidak mendukung tabel/HTML.
  static String buildReceiptText(CheckoutResult result, {PaperSize paperSize = PaperSize.mm58}) {
    final w = paperSize.columns;
    final buf = StringBuffer();

    void line([String s = '']) => buf.writeln(s);
    void divider([String char = '-']) => line(char * w);
    void center(String s) {
      final clean = s.trim();
      if (clean.length >= w) {
        line(clean.substring(0, w));
        return;
      }
      final padLeft = ((w - clean.length) / 2).floor();
      line(' ' * padLeft + clean);
    }

    /// Dua kolom rata kiri & kanan dalam satu baris, membungkus ke baris
    /// baru bila label terlalu panjang untuk lebar kertas.
    void twoCol(String left, String right, {bool bold = false}) {
      final maxLeft = w - right.length - 1;
      if (maxLeft <= 0 || left.length > maxLeft) {
        line(left);
        line(right.padLeft(w));
        return;
      }
      line(left.padRight(w - right.length) + right);
    }

    center(StoreProfile.name);
    center(StoreProfile.address);
    center('Telp: ${StoreProfile.phone}');
    divider('=');
    line('No   : ${result.invoice}');
    line('Tgl  : ${tanggalIndo(result.createdAt)}');
    line('Kasir: ${result.kasirName}');
    line('Bayar: ${result.metode}');
    divider();

    for (final it in result.items) {
      final nama = (it['nama'] ?? '').toString();
      final qtyRaw = it['qty'];
      final hargaRaw = it['harga'];
      final subtotalRaw = it['subtotal'];
      final qty = (qtyRaw is num) ? qtyRaw : num.tryParse('$qtyRaw') ?? 0;
      final harga = (hargaRaw is num) ? hargaRaw : num.tryParse('$hargaRaw') ?? 0;
      final subtotal = (subtotalRaw is num) ? subtotalRaw : num.tryParse('$subtotalRaw') ?? 0;

      line(nama.length > w ? nama.substring(0, w) : nama);
      final detail = '${qty.toStringAsFixed(0)} x ${rupiah(harga)}';
      twoCol(detail, rupiah(subtotal));
    }

    divider();
    twoCol('Subtotal', rupiah(result.subtotal));
    if (result.diskon > 0) twoCol('Diskon', '-${rupiah(result.diskon)}');
    twoCol('TOTAL', rupiah(result.total), bold: true);
    twoCol('Bayar', rupiah(result.bayar));
    twoCol('Kembalian', rupiah(result.kembalian));
    divider('=');
    center(StoreProfile.footerNote);
    line();
    line();
    line();

    return buf.toString();
  }

  /// Kirim [text] ke RawBT lewat skema `rawbt:base64,...`. Menampilkan toast
  /// error yang jelas (bukan crash diam-diam) jika RawBT belum terpasang
  /// atau intent gagal diluncurkan, lengkap dengan tombol untuk membuka
  /// Play Store.
  static Future<void> printToRawBT(BuildContext context, String text) async {
    try {
      final encoded = base64.encode(utf8.encode(text));
      final uri = Uri.parse('rawbt:base64,$encoded');

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        if (!context.mounted) return;
        _showNotInstalledDialog(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      // Kegagalan paling umum di sini adalah RawBT belum terpasang, sehingga
      // tidak ada aplikasi yang bisa menangani skema "rawbt:".
      _showNotInstalledDialog(context);
    }
  }

  /// Alur lengkap: bangun teks struk lalu langsung kirim ke RawBT. Ini yang
  /// dipanggil dari tombol "Cetak Struk".
  static Future<void> printReceipt(
    BuildContext context,
    CheckoutResult result, {
    PaperSize paperSize = PaperSize.mm58,
  }) async {
    final text = buildReceiptText(result, paperSize: paperSize);
    await printToRawBT(context, text);
  }

  static void _showNotInstalledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('RawBT Tidak Ditemukan'),
        content: const Text(
          'Aplikasi RawBT Print Service belum terpasang atau gagal dibuka. '
          'Pasang RawBT terlebih dahulu dari Play Store, atur printer '
          'thermal Anda di dalamnya, lalu coba cetak ulang struk ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final playStoreUri = Uri.parse(_rawBtPlayStoreUrl);
              try {
                await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
              } catch (_) {
                if (ctx.mounted) {
                  showToast(ctx, 'Tidak dapat membuka Play Store.', isError: true);
                }
              }
            },
            child: const Text('Pasang RawBT'),
          ),
        ],
      ),
    );
  }
}
