import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class InventarisScreen extends StatefulWidget {
  const InventarisScreen({super.key});

  @override
  State<InventarisScreen> createState() => _InventarisScreenState();
}

class _InventarisScreenState extends State<InventarisScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({String? search}) {
    setState(() {
      _future = _api.call('inventaris.list', {}).then((res) {
        final resMap = res as Map<String, dynamic>;
        final data = resMap['data'] as List;
        var list = data.map((e) => InventarisRow.fromJson(Map<String, dynamic>.from(e))).toList();
        
        if (search != null && search.isNotEmpty) {
          final s = search.toLowerCase();
          list = list.where((e) => e.namaBarang.toLowerCase().contains(s)).toList();
        }
        
        return {
          'list': list,
        };
      });
    });
  }

  Future<void> _delete(InventarisRow p) async {
    final ok = await confirmDialog(context, title: 'Hapus Inventaris', message: 'Hapus data "${p.namaBarang}"?');
    if (!ok) return;
    try {
      await _api.call('inventaris.delete', {'id': p.id});
      if (mounted) {
        showToast(context, 'Inventaris berhasil dihapus');
        _load(search: _searchCtrl.text);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _showForm([InventarisRow? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InventarisForm(existing: existing),
    ).then((saved) {
      if (saved == true) _load(search: _searchCtrl.text);
    });
  }

  Color _getKondisiColor(String kondisi) {
    switch (kondisi.toUpperCase()) {
      case 'BAIK':
        return Colors.green;
      case 'RUSAK':
        return Colors.orange;
      case 'HILANG':
        return Colors.red;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Inventaris')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Inventaris'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari Nama Barang...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
              ),
              onSubmitted: (v) => _load(search: v),
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
                  final rows = (data['list'] as List?)?.cast<InventarisRow>() ?? [];

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (rows.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(message: 'Belum ada data inventaris', icon: Icons.inventory),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
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
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.inventory, color: AppColors.primary, size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.namaBarang, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.numbers, size: 14, color: AppColors.muted),
                                                  const SizedBox(width: 4),
                                                  Text('${p.jumlah} Unit', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getKondisiColor(p.kondisi).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      p.kondisi.toUpperCase(),
                                                      style: TextStyle(
                                                        color: _getKondisiColor(p.kondisi),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (p.keterangan.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        p.keterangan,
                                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => _showForm(p),
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(6.0),
                                                child: Text('EDIT', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: () => _delete(p),
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(6.0),
                                                child: Text('HAPUS', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
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

class _InventarisForm extends StatefulWidget {
  final InventarisRow? existing;
  const _InventarisForm({this.existing});

  @override
  State<_InventarisForm> createState() => _InventarisFormState();
}

class _InventarisFormState extends State<_InventarisForm> {
  final _api = ApiService.instance;
  final _namaBarangCtrl = TextEditingController();
  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  String _kondisi = 'BAIK';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _namaBarangCtrl.text = widget.existing!.namaBarang;
      _jumlahCtrl.text = widget.existing!.jumlah.toString();
      _keteranganCtrl.text = widget.existing!.keterangan;
      _kondisi = widget.existing!.kondisi;
      if (_kondisi.isEmpty) _kondisi = 'BAIK';
    }
  }

  Future<void> _save() async {
    final nama = _namaBarangCtrl.text.trim();
    final jumlah = _jumlahCtrl.text.trim();
    final ket = _keteranganCtrl.text.trim();

    if (nama.isEmpty) return showToast(context, 'Nama Barang wajib diisi', isError: true);
    if (jumlah.isEmpty || int.tryParse(jumlah) == null) return showToast(context, 'Jumlah tidak valid', isError: true);

    setState(() => _saving = true);
    try {
      await _api.call('inventaris.save', {
        'id': widget.existing?.id ?? '',
        'nama_barang': nama,
        'jumlah': jumlah,
        'kondisi': _kondisi,
        'keterangan': ket,
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
          Text(isEdit ? 'Edit Inventaris' : 'Tambah Inventaris', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _namaBarangCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Barang',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _jumlahCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _kondisi,
            decoration: const InputDecoration(
              labelText: 'Kondisi',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'BAIK', child: Text('Baik')),
              DropdownMenuItem(value: 'RUSAK', child: Text('Rusak')),
              DropdownMenuItem(value: 'HILANG', child: Text('Hilang')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _kondisi = v);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keteranganCtrl,
            decoration: const InputDecoration(
              labelText: 'Keterangan (opsional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
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
