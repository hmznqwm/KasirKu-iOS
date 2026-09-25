import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/local_helpers.dart';
import '../utils/formatters.dart';

class PengeluaranScreen extends StatefulWidget {
  const PengeluaranScreen({super.key});

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<Map<String, dynamic>>? _future;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
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
      _load(search: _searchCtrl.text);
    }
  }

  void _load({String? search}) {
    setState(() {
      _future = _api.call('pengeluaran.list', {'search': search ?? ''}).then((res) {
        final resMap = res as Map<String, dynamic>;
        final data = resMap['data'] as List;
        final list = data.map((e) => PengeluaranRow.fromJson(Map<String, dynamic>.from(e))).toList();
        return {
          'list': list,
          'modalHariIni': resMap['modalHariIni'] ?? 0,
          'modalBulanIni': resMap['modalBulanIni'] ?? 0,
        };
      });
    });
  }

  Future<void> _delete(PengeluaranRow p) async {
    final ok = await confirmDialog(context, title: 'Hapus Pengeluaran', message: 'Hapus catatan "${p.keterangan}" (${rupiah(p.jumlah)})?');
    if (!ok) return;
    try {
      await _api.call('pengeluaran.delete', {'id': p.id});
      if (mounted) {
        showToast(context, 'Pengeluaran berhasil dihapus');
        _load(search: _searchCtrl.text);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _showForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PengeluaranForm(),
    ).then((saved) {
      if (saved == true) _load(search: _searchCtrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
        icon: const Icon(Icons.add),
        label: const Text('Catat Belanja'),
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
                      hintText: 'Cari keterangan...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
                    ),
                    onSubmitted: (v) => _load(search: v),
                  ),
                ),
                const SizedBox(width: 8),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _load(search: _searchCtrl.text);
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
              onRefresh: () async => _load(search: _searchCtrl.text),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snap.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ErrorView(message: snap.error.toString(), onRetry: () => _load(search: _searchCtrl.text)),
                    );
                  }
                  final data = snap.data ?? {};
                  final rows = (data['list'] as List?)?.cast<PengeluaranRow>() ?? [];
                  final modalHariIni = (data['modalHariIni'] as num?)?.toDouble() ?? 0.0;
                  final modalBulanIni = (data['modalBulanIni'] as num?)?.toDouble() ?? 0.0;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              StatCard(
                                label: 'Modal Belanja (Hari Ini)',
                                value: rupiah(modalHariIni),
                                icon: Icons.account_balance_wallet,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 10),
                              StatCard(
                                label: 'Modal Belanja (Bulan Ini)',
                                value: rupiah(modalBulanIni),
                                icon: Icons.date_range,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (rows.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(message: 'Belum ada catatan pengeluaran', icon: Icons.receipt_long),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final p = rows[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SectionCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward, color: AppColors.danger, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.keterangan, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(tanggalPendek(p.tanggal), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  if (p.kasirName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('Oleh: ${p.kasirName}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                                  ]
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(rupiah(p.jumlah), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _delete(p),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Text('HAPUS', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: rows.length,
                ),
              ),
            ),
        ],
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

class _PengeluaranForm extends StatefulWidget {
  const _PengeluaranForm();

  @override
  State<_PengeluaranForm> createState() => _PengeluaranFormState();
}

class _PengeluaranFormState extends State<_PengeluaranForm> {
  final _api = ApiService.instance;
  final _ketCtrl = TextEditingController();
  final _jmlCtrl = TextEditingController();
  DateTime _tanggal = DateTime.now();
  bool _saving = false;

  Future<void> _save() async {
    final ket = _ketCtrl.text.trim();
    final jml = double.tryParse(_jmlCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (ket.isEmpty) return showToast(context, 'Keterangan wajib diisi', isError: true);
    if (jml <= 0) return showToast(context, 'Jumlah tidak valid', isError: true);

    setState(() => _saving = true);
    try {
      await _api.call('pengeluaran.save', {
        'tanggal': '${_tanggal.year}-${pad2(_tanggal.month)}-${pad2(_tanggal.day)}',
        'keterangan': ket,
        'jumlah': jml,
      });
      if (mounted) {
        showToast(context, 'Tersimpan');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) setState(() => _tanggal = d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Catat Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_tanggal.day}/${_tanggal.month}/${_tanggal.year}'),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ketCtrl,
            decoration: const InputDecoration(
              labelText: 'Keterangan Belanja',
              hintText: 'Misal: Beli gas, gula, dll',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jmlCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Total Rupiah',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}
