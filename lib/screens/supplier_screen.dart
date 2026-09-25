import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
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
      _future = _api.call('supplier.list', {'search': search ?? ''}).then((res) {
        final resMap = res as Map<String, dynamic>;
        final data = resMap['data'] as List;
        final list = data.map((e) => SupplierRow.fromJson(Map<String, dynamic>.from(e))).toList();
        return {
          'list': list,
        };
      });
    });
  }

  Future<void> _delete(SupplierRow p) async {
    final ok = await confirmDialog(context, title: 'Hapus Supplier', message: 'Hapus data "${p.namaPt}"?');
    if (!ok) return;
    try {
      await _api.call('supplier.delete', {'id': p.id});
      if (mounted) {
        showToast(context, 'Supplier berhasil dihapus');
        _load(search: _searchCtrl.text);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _showForm([SupplierRow? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierForm(existing: existing),
    ).then((saved) {
      if (saved == true) _load(search: _searchCtrl.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Supplier')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Supplier'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari Nama PT atau Nomor...',
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
                  final rows = (data['list'] as List?)?.cast<SupplierRow>() ?? [];

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (rows.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(message: 'Belum ada data supplier', icon: Icons.business),
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
                                          child: const Icon(Icons.business, color: AppColors.primary, size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.namaPt, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 14, color: AppColors.muted),
                                                  const SizedBox(width: 4),
                                                  Text(p.nomor.isEmpty ? '-' : p.nomor, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Padding(
                                                    padding: EdgeInsets.only(top: 2),
                                                    child: Icon(Icons.location_on, size: 14, color: AppColors.muted),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(p.alamat.isEmpty ? '-' : p.alamat, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
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

class _SupplierForm extends StatefulWidget {
  final SupplierRow? existing;
  const _SupplierForm({this.existing});

  @override
  State<_SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<_SupplierForm> {
  final _api = ApiService.instance;
  final _namaPtCtrl = TextEditingController();
  final _nomorCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _namaPtCtrl.text = widget.existing!.namaPt;
      _nomorCtrl.text = widget.existing!.nomor;
      _alamatCtrl.text = widget.existing!.alamat;
    }
  }

  Future<void> _save() async {
    final namaPt = _namaPtCtrl.text.trim();
    final nomor = _nomorCtrl.text.trim();
    final alamat = _alamatCtrl.text.trim();

    if (namaPt.isEmpty) return showToast(context, 'Nama PT wajib diisi', isError: true);

    setState(() => _saving = true);
    try {
      await _api.call('supplier.save', {
        'id': widget.existing?.id ?? '',
        'nama_pt': namaPt,
        'nomor': nomor,
        'alamat': alamat,
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
          Text(isEdit ? 'Edit Supplier' : 'Tambah Supplier', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _namaPtCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama PT',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomorCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor (Telepon/HP)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _alamatCtrl,
            decoration: const InputDecoration(
              labelText: 'Alamat',
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
