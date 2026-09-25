import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Service untuk mengelola foto produk secara offline.
///
/// Foto yang dipilih pengguna di-copy ke folder permanen di dalam
/// direktori penyimpanan aplikasi (tidak butuh internet sama sekali).
/// Path file lokal itulah yang disimpan di database SQLite.
class FotoService {
  FotoService._();
  static final FotoService instance = FotoService._();

  /// Sub-direktori di dalam documents dir khusus foto produk.
  static const _subDir = 'produk_foto';

  /// Buka image picker, copy foto ke penyimpanan aplikasi, dan kembalikan
  /// path lokal. Mengembalikan `null` jika pengguna membatalkan.
  Future<String?> pickAndSave({String? oldPath}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    if (picked.path == null) return null;

    final srcFile = File(picked.path!);
    if (!srcFile.existsSync()) return null;

    // Validasi ukuran maksimal 200 KB
    final sizeBytes = srcFile.lengthSync();
    if (sizeBytes > 200 * 1024) {
      throw Exception('Ukuran foto maksimal 200 KB');
    }

    // Buat direktori tujuan bila belum ada
    final dir = await _fotoDir();
    await dir.create(recursive: true);

    // Nama file: timestamp + ekstensi asli supaya unik
    final ext = p.extension(picked.path!).toLowerCase();
    final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, filename));

    // Copy file ke penyimpanan app
    await srcFile.copy(dest.path);

    // Hapus foto lama jika ada
    if (oldPath != null && oldPath.isNotEmpty) {
      await deletePhoto(oldPath);
    }

    return dest.path;
  }

  /// Hapus file foto dari disk. Tidak melempar exception jika file tidak ada.
  Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // Abaikan error hapus file — tidak kritis
    }
  }

  /// Kembalikan [File] jika path valid & file ada, atau `null` jika tidak.
  File? getFile(String? path) {
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }

  /// Direktori penyimpanan foto produk di dalam storage aplikasi.
  Future<Directory> _fotoDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, _subDir));
  }
}
