import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const dbPath = 'C:/Users/hmznq/Downloads/WebKu/kasirku_mobile_flutter_offline/.dart_tool/sqflite_common_ffi/databases/kasirku_offline.db';
  if (!File(dbPath).existsSync()) {
    print('DB does not exist at \$dbPath');
    return;
  }
  final db = await databaseFactory.openDatabase(dbPath);
  final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier', 'inventaris', 'audit_logs'];
  
  for (final table in tables) {
    try {
      final count = await db.update(table, {'sync_status': 0}, where: 'is_deleted = 1');
      if (count > 0) {
        print('Reset sync_status for \$count deleted rows in \$table');
      }
    } catch (e) {
      // Some tables might not have is_deleted
    }
  }
  await db.close();
  print('Done.');
}
