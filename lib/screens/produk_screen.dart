import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/foto_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../services/event_provider.dart';
import 'produk_form_screen.dart';
import 'produk_import_screen.dart';

// Helpers removed since subKategori is a real column now


class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<List<Produk>>? _future;
  final Set<String> _selected = {};
  bool _selectMode = false;
  String _selectedKategori = '';    // '' = semua
  String _selectedSubKategori = ''; // Sub kategori, '' = semua
  
  late EventProvider _ev;
  int _localProdukVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localProdukVersion = _ev.produkVersion;
    _ev.addListener(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _ev.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    if (_localProdukVersion != _ev.produkVersion) {
      _localProdukVersion = _ev.produkVersion;
      if (mounted) _load(q: _searchCtrl.text);
    }
  }

  void _load({String? q}) {
    setState(() {
      _selected.clear();
      _selectMode = false;
      _future = _api.call('produk.list', {'q': q ?? ''}).then(
          (d) => (d as List).map((e) => Produk.fromJson(Map<String, dynamic>.from(e))).toList());
    });
  }

  Future<void> _delete(Produk p) async {
    final ok = await confirmDialog(context, title: 'Hapus Produk', message: 'Hapus produk "${p.nama}"?');
    if (!ok) return;
    try {
      await _api.call('produk.delete', {'id': p.id});
      if (mounted) {
        context.read<EventProvider>().refreshProduk();
        showToast(context, 'Produk berhasil dihapus');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _deleteMassal() async {
    if (_selected.isEmpty) return;
    final ok = await confirmDialog(context,
        title: 'Hapus Produk', message: 'Hapus ${_selected.length} produk terpilih?');
    if (!ok) return;
    try {
      await _api.call('produk.deleteMassal', {'ids': _selected.toList()});
      if (mounted) {
        setState(() {
          _selected.clear();
          _selectMode = false;
        });
        context.read<EventProvider>().refreshProduk();
        showToast(context, 'Produk terpilih berhasil dihapus');
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  void _showProductOptions(Produk p) {
    final isAdmin = context.read<AuthProvider>().me?.isAdmin ?? false;
    if (!isAdmin) return;
    
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
              child: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center, maxLines: 2),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Edit Produk'),
              onTap: () async {
                Navigator.pop(ctx);
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => ProdukFormScreen(produk: p)),
                );
                if (saved == true) {
                  _load(q: _searchCtrl.text);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Hapus Produk', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(p);
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

        title: const Text('Produk'),
        actions: [
          if (isAdmin && _selectMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _selected.isEmpty ? null : _deleteMassal,
            ),
          if (isAdmin && !_selectMode)
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Import Produk Massal',
              onPressed: () async {
                final imported = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProdukImportScreen()),
                );
                if (imported == true) _load(q: _searchCtrl.text);
              },
            ),
          if (isAdmin)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist_outlined),
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                _selected.clear();
              }),
            ),
        ],
      ),
      floatingActionButton: (isAdmin && _selectMode && _selected.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _deleteMassal,
              backgroundColor: AppColors.danger,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: Text('Hapus Terpilih (${_selected.length})', style: const TextStyle(color: Colors.white)),
            )
          : (isAdmin && !_selectMode)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const ProdukFormScreen()),
                    );
                    if (saved == true) _load(q: _searchCtrl.text);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Produk'),
                )
              : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama, kode, atau kategori...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
              onSubmitted: (_) => setState(() {}),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // ── Filter Kategori 2 tingkat ────────────────────────────────
          FutureBuilder<List<Produk>>(
            future: _future,
            builder: (context, snap) {
              final allData = snap.data ?? [];
              final aktif = allData.where((p) => p.status.toUpperCase() != 'HAPUS');
              final indukSet = aktif
                  .map((p) => p.kategori)
                  .where((k) => k.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
              final subSet = _selectedKategori.isEmpty
                  ? <String>[]
                  : aktif
                      .where((p) => p.kategori == _selectedKategori)
                      .map((p) => p.subKategori)
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
              if (indukSet.isEmpty) return const SizedBox.shrink();
              return _ProdukDualKategoriBar(
                indukList: indukSet,
                subList: subSet,
                selectedInduk: _selectedKategori,
                selectedSub: _selectedSubKategori,
                onIndukSelected: (k) => setState(() {
                  _selectedKategori = k;
                  _selectedSubKategori = '';
                }),
                onSubSelected: (s) => setState(() => _selectedSubKategori = s),
              );
            },
          ),
          Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _selectedKategori = '';
                    _selectedSubKategori = '';
                    _load(q: _searchCtrl.text);
                  },
              child: FutureBuilder<List<Produk>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
                  if (snap.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ErrorView(message: snap.error.toString(), onRetry: () => _load(q: _searchCtrl.text)),
                    );
                  }
                  final all = snap.data ?? [];
                  // Filter kategori 2 tingkat + pencarian teks (client-side)
                  final q = _searchCtrl.text.toLowerCase();
                  final list = all.where((p) {
                    if (_selectedKategori.isNotEmpty &&
                        p.kategori != _selectedKategori) { return false; }
                    if (_selectedSubKategori.isNotEmpty &&
                        p.subKategori != _selectedSubKategori) { return false; }
                    if (q.isNotEmpty) {
                      return p.nama.toLowerCase().contains(q) ||
                          p.kode.toLowerCase().contains(q) ||
                          p.kategori.toLowerCase().contains(q);
                    }
                    return true;
                  }).toList();
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [EmptyState(
                        message: _selectedKategori.isNotEmpty
                            ? 'Tidak ada produk di kategori "$_selectedKategori"'
                            : 'Belum ada produk',
                        icon: Icons.inventory_2_outlined)],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = list[i];

                      return GestureDetector(
                        onLongPress: () => _showProductOptions(p),
                        onTap: _selectMode ? () {
                          setState(() {
                            if (_selected.contains(p.id)) {
                              _selected.remove(p.id);
                            } else {
                              _selected.add(p.id);
                            }
                          });
                        } : null,
                        child: SectionCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail foto produk dengan overlay seleksi
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  _ProdukThumbnail(fotoPath: p.foto),
                                  if (_selectMode && _selected.contains(p.id))
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                                    ),
                                  if (_selectMode && !_selected.contains(p.id))
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.circle_outlined, color: Colors.white70, size: 20),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(p.nama,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14.5)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text('${p.kode} • ${p.kategori} • ${p.satuan}',
                                        style: const TextStyle(
                                            color: AppColors.muted, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('Jual: ${rupiah(p.hargaJual)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppColors.primary)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

// ---------------------------------------------------------------------------
// Thumbnail foto produk — tampilkan foto lokal atau placeholder ikon
// ---------------------------------------------------------------------------

class _ProdukThumbnail extends StatelessWidget {
  final String fotoPath;
  const _ProdukThumbnail({required this.fotoPath});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = const Icon(Icons.image_outlined,
        size: 28, color: AppColors.border);
        
    if (fotoPath.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: fotoPath, 
        fit: BoxFit.cover,
        placeholder: (context, url) => const Icon(Icons.image_outlined, size: 28, color: AppColors.border),
        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, size: 28, color: AppColors.border),
      );
    } else if (fotoPath.isNotEmpty) {
      final file = FotoService.instance.getFile(fotoPath);
      if (file != null) {
        imageWidget = Image.file(file, fit: BoxFit.cover);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 60,
        height: 60,
        color: AppColors.bg,
        child: imageWidget,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip bar filter kategori 2 tingkat untuk halaman Produk
// ---------------------------------------------------------------------------

class _ProdukDualKategoriBar extends StatelessWidget {
  final List<String> indukList;
  final List<String> subList;
  final String selectedInduk;
  final String selectedSub;
  final ValueChanged<String> onIndukSelected;
  final ValueChanged<String> onSubSelected;

  const _ProdukDualKategoriBar({
    required this.indukList,
    required this.subList,
    required this.selectedInduk,
    required this.selectedSub,
    required this.onIndukSelected,
    required this.onSubSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Kategori Utama
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              _chip('', 'Semua', selectedInduk, onIndukSelected, isPrimary: true),
              ...indukList.map((k) => _chip(k, k, selectedInduk, onIndukSelected, isPrimary: true)),
            ],
          ),
        ),
        // Baris 2: Sub Kategori (hanya jika ada sub)
        if (selectedInduk.isNotEmpty && subList.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              children: [
                _chip('', 'Semua $selectedInduk', selectedSub, onSubSelected, isPrimary: false),
                ...subList.map((s) => _chip(s, s, selectedSub, onSubSelected, isPrimary: false)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip(
    String value,
    String label,
    String currentSelected,
    ValueChanged<String> onTap, {
    required bool isPrimary,
  }) {
    final isSelected = currentSelected == value;
    final color = isPrimary ? AppColors.primary : AppColors.primary.withValues(alpha: 0.75);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTap(isSelected ? '' : value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
