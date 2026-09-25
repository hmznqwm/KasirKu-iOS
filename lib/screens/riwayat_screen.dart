import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../services/event_provider.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<List<TransaksiRow>>? _future;
  DateTimeRange? _dateRange;
  
  late EventProvider _ev;
  int _localTransaksiVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localTransaksiVersion = _ev.transaksiVersion;
    _ev.addListener(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _ev.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    if (_localTransaksiVersion != _ev.transaksiVersion) {
      _localTransaksiVersion = _ev.transaksiVersion;
      if (mounted) _load(q: _searchCtrl.text);
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
      _load(q: _searchCtrl.text);
    }
  }

  void _load({String? q}) {
    setState(() {
      _future = _api.call('transaksi.list', {'q': q ?? ''}).then(
          (d) => (d as List).map((e) => TransaksiRow.fromJson(Map<String, dynamic>.from(e))).toList());
    });
  }

  Future<void> _delete(TransaksiRow r) async {
    final ok = await confirmDialog(context,
        title: 'Hapus Transaksi', message: 'Hapus transaksi ${r.invoice}?');
    if (!ok) return;
    try {
      await _api.call('transaksi.delete', {'id': r.id});
      if (mounted) {
        context.read<EventProvider>().refreshTransaksi();
        context.read<EventProvider>().refreshProduk();
        showToast(context, 'Transaksi berhasil dihapus');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _refund(TransaksiRow r) async {
    final ok = await confirmDialog(context,
        title: 'Refund Transaksi', message: 'Refund transaksi ${r.invoice}? Uang akan dikembalikan ke pelanggan.');
    if (!ok) return;
    try {
      await _api.call('transaksi.refund', {'id': r.id});
      if (mounted) {
        context.read<EventProvider>().refreshTransaksi();
        showToast(context, 'Transaksi berhasil di-refund');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _showHistoryOptions(TransaksiRow head, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(head.invoice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center, maxLines: 2),
            ),
            const SizedBox(height: 16),
            if (head.status != 'REFUND')
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: const Text('Refund Transaksi', style: TextStyle(color: Colors.orange)),
                subtitle: const Text('Dana dikembalikan, transaksi ditandai refund'),
                onTap: () {
                  Navigator.pop(ctx);
                  _refund(head);
                },
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Hapus Transaksi', style: TextStyle(color: AppColors.danger)),
                subtitle: const Text('Menghapus data transaksi secara permanen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(head);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().me?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(

        title: const Text('Riwayat Transaksi')
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari invoice, kasir, atau metode...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
                    ),
                    onSubmitted: (v) => _load(q: v),
                  ),
                ),
                const SizedBox(width: 8),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _load(q: _searchCtrl.text);
                    },
                    tooltip: 'Hapus Filter',
                  ),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: _selectDateRange,
                  tooltip: 'Filter Tanggal',
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(q: _searchCtrl.text),
              child: FutureBuilder<List<TransaksiRow>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snap.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ErrorView(message: snap.error.toString(), onRetry: () => _load(q: _searchCtrl.text)),
                    );
                  }
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [EmptyState(message: 'Belum ada transaksi', icon: Icons.receipt_long_outlined)],
                    );
                  }
                  // Kelompokkan baris per invoice, seperti tampilan tabel di versi web
                  final grouped = <String, List<TransaksiRow>>{};
                  for (final r in rows) {
                    grouped.putIfAbsent(r.invoice, () => []).add(r);
                  }
                  final invoices = grouped.keys.toList();

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final inv = invoices[i];
                      final items = grouped[inv]!;
                      final head = items.first;
                      return GestureDetector(
                        onLongPress: () => _showHistoryOptions(head, isAdmin),
                        child: SectionCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(head.invoice, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        if (head.status == 'REFUND') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('REFUND', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  StatusPill(text: head.metode, bg: AppColors.stockOkBg, fg: AppColors.stockOkText),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${tanggalIndo(head.createdAt)} • Kasir: ${head.kasirName}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              const SizedBox(height: 8),
                              ...items.map((it) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• ${it.namaBarang} x${angka(it.jumlah)}',
                                        style: const TextStyle(fontSize: 12.5)),
                                  )),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Total: ${rupiah(head.total)}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13.5)),
                                  ),
                                  Text('Bayar: ${rupiah(head.bayar)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
