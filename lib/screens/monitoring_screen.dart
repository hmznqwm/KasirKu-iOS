import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:intl/intl.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _logs = [];
  DateTimeRange? _dateRange;
  String _error = '';
  Timer? _autoRefreshTimer;

  void _applyFilter() {
    _fetchLogs();
  }

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    // Auto-refresh log setiap 8 detik saat admin membuka layar monitoring
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isLoading) {
        _fetchLogs(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLogs({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      // Sinkronisasi data dari Supabase agar log aktivitas kasir langsung masuk
      await SyncService.instance.syncData();

      final p = <String, dynamic>{};
      if (_dateRange != null) {
        p['start_date'] = _dateRange!.start.toString().split(' ')[0];
        p['end_date'] = _dateRange!.end.toString().split(' ')[0];
      }
      final res = await ApiService.instance('monitoring.list', p);
      final data = res['data'];
      if (mounted) {
        setState(() {
          _logs = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

    Future<void> _selectDateRange() async {
    DateTime? start = _dateRange?.start;
    DateTime? end = _dateRange?.end;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Filter Tanggal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dari Tanggal'),
                    subtitle: Text(start != null ? start!.toString().split(' ')[0] : 'Pilih Tanggal'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: start ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setStateSB(() => start = p);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sampai Tanggal'),
                    subtitle: Text(end != null ? end!.toString().split(' ')[0] : 'Pilih Tanggal'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: end ?? start ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setStateSB(() => end = p);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (start != null && end != null) {
                      if (end!.isBefore(start!)) {
                        final temp = start;
                        start = end;
                        end = temp;
                      }
                      Navigator.pop(context, DateTimeRange(start: start!, end: end!));
                    } else if (start != null) {
                      Navigator.pop(context, DateTimeRange(start: start!, end: start!));
                    } else if (end != null) {
                      Navigator.pop(context, DateTimeRange(start: end!, end: end!));
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Monitoring Log', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
        actions: [
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                setState(() => _dateRange = null);
                _applyFilter();
              },
              tooltip: 'Hapus Filter',
            ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter Tanggal',
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty && _logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLogs,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
              )
            ],
          ),
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Belum ada log aktivitas', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final log = _logs[index];
          final action = (log['action'] ?? '').toString().toUpperCase();
          final entity = (log['entity'] ?? '').toString();
          final details = (log['details'] ?? '').toString();
          final userName = (log['user_name'] ?? '').toString();
          
          Color actionColor = AppColors.primary;
          if (action == 'DELETE') {
            actionColor = AppColors.danger;
          } else if (action == 'UPDATE') {
            actionColor = Colors.orange;
          } else if (action == 'CREATE' || action == 'SAVE') {
            actionColor = AppColors.stockOkBg;
          }

          DateTime? createdAt;
          if (log['created_at'] != null) {
            createdAt = DateTime.tryParse(log['created_at'].toString());
          }

          return SectionCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          action == 'DELETE' ? Icons.delete_outline :
                          action == 'UPDATE' ? Icons.edit_outlined :
                          Icons.add_circle_outline,
                          size: 18,
                          color: actionColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$action $entity',
                          style: TextStyle(fontWeight: FontWeight.w800, color: actionColor, fontSize: 14),
                        ),
                      ],
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('dd MMM yy HH:mm').format(createdAt.toLocal()),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'User: $userName',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    details,
                    style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
