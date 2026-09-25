import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_helper.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _supabase = Supabase.instance.client;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  Future<void> init() async {
    // Listen to network changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        syncData();
      }
    });

    // Run initial sync
    final results = await Connectivity().checkConnectivity();
    if (!results.contains(ConnectivityResult.none)) {
      syncData();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint('Starting background sync...');
    try {
      await _pushLocalChanges();
      await _pullRemoteChanges();
      debugPrint('Background sync completed.');
    } catch (e) {
      debugPrint('Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Reset semua sync_status ke 0 agar semua data lokal dipush ulang ke Supabase
  Future<void> forceSyncAll() async {
    _isSyncing = false; // allow re-run
    final db = await AppDatabase.instance.db;
    final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier', 'inventaris', 'audit_logs'];
    for (final table in tables) {
      await db.update(table, {'sync_status': 0});
    }
    debugPrint('[Sync] All sync_status reset to 0. Starting force sync...');
    await syncData();
  }

  Future<void> _pushLocalChanges() async {
    final db = await AppDatabase.instance.db;
    // audit_logs is now fixed (RLS works), so we include it
    final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier', 'inventaris', 'audit_logs'];

    for (final table in tables) {
      // Find unsynced rows
      final unsynced = await db.query(table, where: 'sync_status = 0');
      if (unsynced.isEmpty) continue;

      debugPrint('[Sync] Pushing ${unsynced.length} rows for table $table');
      for (final row in unsynced) {
        try {
          final rowData = Map<String, dynamic>.from(row);
          final idCol = table == 'settings' ? 'key' : 'id';
          
          if (rowData['is_deleted'] == 1) {
            // Hard delete from Supabase
            await _supabase.from(table).delete().eq(idCol, rowData[idCol]);
            // Hard delete from local SQLite
            await db.delete(table, where: '$idCol = ?', whereArgs: [rowData[idCol]]);
            debugPrint('[Sync] ✓ Hard Deleted $table/${rowData[idCol]}');
          } else {
            // Remove local-only column
            rowData.remove('sync_status');
            
            // Ensure last_modified is never null (NOT NULL constraint in Supabase)
            if (rowData['last_modified'] == null || rowData['last_modified'].toString().isEmpty) {
              rowData['last_modified'] = DateTime.now().toUtc().toIso8601String();
            }

            // Upsert to Supabase
            await _supabase.from(table).upsert(rowData);

            // Mark as synced locally
            await db.update(
              table,
              {'sync_status': 1},
              where: '$idCol = ?',
              whereArgs: [row[idCol]],
            );
            debugPrint('[Sync] ✓ Pushed $table/${row[idCol]}');
          }
        } catch (e) {
          debugPrint('[Sync] ✗ Failed to push row in $table: $e');
        }
      }
    }
  }

  Future<void> _pullRemoteChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.instance.db;
    final tables = ['users', 'produk', 'settings', 'transaksi', 'transaksi_detail', 'pengeluaran', 'supplier', 'inventaris', 'audit_logs'];

    for (final table in tables) {
      final lastSyncKey = 'sync_last_time_$table';
      final lastSyncStr = prefs.getString(lastSyncKey) ?? '1970-01-01 00:00:00';
      
      final response = await _supabase
          .from(table)
          .select()
          .gt('last_modified', lastSyncStr)
          .order('last_modified', ascending: true);

      if (response.isEmpty) continue;

      debugPrint('Pulling ${response.length} rows for table $table');
      
      String maxLastModified = lastSyncStr;

      for (final row in response) {
        final rowData = Map<String, dynamic>.from(row);
        rowData['sync_status'] = 1; // Mark as synced

        if (table == 'settings') {
          final count = await db.update(
            table,
            rowData,
            where: 'key = ?',
            whereArgs: [row['key']],
          );
          if (count == 0) {
            await db.insert(table, rowData);
          }
        } else {
          final count = await db.update(
            table,
            rowData,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          if (count == 0) {
            await db.insert(table, rowData);
          }
        }

        if (row['last_modified'] != null) {
          final rowMod = row['last_modified'].toString();
          if (rowMod.compareTo(maxLastModified) > 0) {
            maxLastModified = rowMod;
          }
        }
      }

      await prefs.setString(lastSyncKey, maxLastModified);

      // Reconcile remote deletions: if a synced row was deleted from Supabase dashboard, delete it locally
      try {
        final idCol = table == 'settings' ? 'key' : 'id';
        final remoteIdsResp = await _supabase.from(table).select(idCol);
        final remoteIds = (remoteIdsResp as List)
            .map((r) => r[idCol]?.toString())
            .where((id) => id != null)
            .toSet();

        final localRows = await db.query(table, columns: [idCol], where: 'sync_status = 1');
        for (final localRow in localRows) {
          final localId = localRow[idCol]?.toString();
          if (localId != null && !remoteIds.contains(localId)) {
            await db.delete(table, where: '$idCol = ?', whereArgs: [localRow[idCol]]);
            debugPrint('[Sync] 🗑️ Remote-deleted item purged locally: $table/$localId');
          }
        }
      } catch (e) {
        debugPrint('[Sync] Remote deletion check for $table skipped or failed: $e');
      }
    }
  }
}
