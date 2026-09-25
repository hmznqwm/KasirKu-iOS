import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/foto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../services/event_provider.dart';
import '../utils/formatters.dart';

class ProdukFormScreen extends StatefulWidget {
  final Produk? produk;
  const ProdukFormScreen({super.key, this.produk});

  @override
  State<ProdukFormScreen> createState() => _ProdukFormScreenState();
}

class _ProdukFormScreenState extends State<ProdukFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService.instance;
  final _foto = FotoService.instance;

  late final _kode = TextEditingController(text: widget.produk?.kode ?? '');
  late final _nama = TextEditingController(text: widget.produk?.nama ?? '');
  late final _hargaBeli = TextEditingController(
      text: widget.produk != null ? widget.produk!.hargaBeli.toStringAsFixed(0) : '');
  late final _hargaJual = TextEditingController(
      text: widget.produk != null ? widget.produk!.hargaJual.toStringAsFixed(0) : '');
  late final _hargaJual2 = TextEditingController(
      text: widget.produk != null && widget.produk!.hargaJual2 > 0
          ? widget.produk!.hargaJual2.toStringAsFixed(0)
          : '');

  // ── State kategori 2 tingkat ─────────────────────────────────────────────
  String? _kategoriInduk;   // misal: "Minuman"
  String? _kategoriSub;     // misal: "Kopi" (opsional)
  String? _satuan;
  List<String> _indukOptions = [];
  List<String> _subOptions   = [];   // semua sub dari settings
  List<String> _satuanOptions = [];
  bool _loadingOptions = true;
  bool _saving = false;

  /// Path foto yang saat ini aktif (path lokal file atau kosong).
  String _fotoPath = '';

  /// Flag: apakah foto sudah diganti dari nilai awal widget.produk?.foto
  bool _fotoChanged = false;

  bool get _isEdit => widget.produk != null;

  @override
  void initState() {
    super.initState();
    _fotoPath = widget.produk?.foto ?? '';
    _loadOptions();
  }

  @override
  void dispose() {
    _kode.dispose();
    _nama.dispose();
    _hargaBeli.dispose();
    _hargaJual.dispose();
    _hargaJual2.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final data = await _api.call('master.options');
      final map = Map<String, dynamic>.from(data);
      final indukList  = List<String>.from(map['kategoriInduk'] ?? []);
      final subList    = List<String>.from(map['kategoriSub']   ?? []);
      final satuanList = List<String>.from(map['satuan']        ?? []);

      // Parse kategori produk yang sedang diedit (langsung dari model)
      String? initInduk = widget.produk?.kategori;
      if (initInduk != null && initInduk.isEmpty) initInduk = null;
      String? initSub = widget.produk?.subKategori;
      if (initSub != null && initSub.isEmpty) initSub = null;

      // Pastikan nilai edit ada dalam list opsi
      if (initInduk != null && !indukList.contains(initInduk)) {
        indukList.add(initInduk);
      }
      if (initSub != null && !subList.contains(initSub)) {
        subList.add(initSub);
      }

      _kategoriInduk = initInduk;
      _kategoriSub = initSub;
      _satuan = widget.produk?.satuan ?? '';

      setState(() {
        _indukOptions = List<String>.from(indukList);
        _subOptions = List<String>.from(subList);
        _satuanOptions = List<String>.from(satuanList);

        // Safeguard: Ensure the current product's category and unit exist in the options
        if (_kategoriInduk != null && !_indukOptions.contains(_kategoriInduk)) {
          _indukOptions.add(_kategoriInduk!);
        }
        if (_kategoriSub != null && !_subOptions.contains(_kategoriSub)) {
          _subOptions.add(_kategoriSub!);
        }
        if (_satuan != null && !_satuanOptions.contains(_satuan)) {
          _satuanOptions.add(_satuan!);
        }

        _kategoriInduk = _indukOptions.contains(_kategoriInduk)
            ? _kategoriInduk
            : (_indukOptions.isNotEmpty ? _indukOptions.first : null);

        final satuanCheck = _satuanOptions.where((e) => e.toUpperCase() == _satuan?.toUpperCase()).toList();
        _satuan = satuanCheck.isNotEmpty
            ? satuanCheck.first
            : (_satuanOptions.isNotEmpty ? _satuanOptions.first : null);
        _loadingOptions = false;
      });
    } catch (e) {
      setState(() => _loadingOptions = false);
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _addMasterOption(String type) async {
    final isInduk = type == 'KATEGORI_INDUK';
    final isSub   = type == 'KATEGORI_SUB';
    final ctrl = TextEditingController();
    final label = isInduk ? 'Kategori Utama' : isSub ? 'Sub Kategori' : 'Satuan';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah $label'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nama baru')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      await _api.call('master.option.add', {'type': type, 'value': value});
      setState(() {
        if (isInduk) {
          _indukOptions = [..._indukOptions, value];
          _kategoriInduk = value;
          _kategoriSub = null; // reset sub ketika induk baru ditambah
        } else if (isSub) {
          _subOptions = [..._subOptions, value];
          _kategoriSub = value;
        } else {
          _satuanOptions = [..._satuanOptions, value];
          _satuan = value;
        }
      });
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // FOTO
  // ---------------------------------------------------------------------------

  Future<void> _pickFoto() async {
    // oldPath: hanya hapus jika foto memang sudah diganti sebelumnya
    // (bila belum diganti, path lama masih milik widget.produk — API yang
    // akan mempertahankannya; kalau diganti lagi, file intermediate juga dihapus).
    try {
      final newPath = await _foto.pickAndSave(
        oldPath: _fotoChanged ? _fotoPath : null,
      );
      if (newPath == null) return; // user batal
      setState(() {
        _fotoPath = newPath;
        _fotoChanged = true;
      });
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _hapusFoto() async {
    final ok = await confirmDialog(context,
        title: 'Hapus Foto',
        message: 'Yakin ingin menghapus foto produk ini?');
    if (!ok) return;
    if (_fotoChanged && _fotoPath.isNotEmpty) {
      await _foto.deletePhoto(_fotoPath);
    }
    setState(() {
      _fotoPath = '';
      _fotoChanged = true;
    });
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final isAdmin = context.read<AuthProvider>().me?.isAdmin ?? false;
    if (!isAdmin) {
      showToast(context, 'Akses ditolak: Kasir tidak diizinkan mengubah/menambah produk', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_kategoriInduk == null || _kategoriInduk!.isEmpty) {
      showToast(context, 'Kategori Utama wajib dipilih', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.call('produk.save', {
        if (_isEdit) 'id': widget.produk!.id,
        'kode': _kode.text.trim(),
        'nama': _nama.text.trim(),
        'kategori': _kategoriInduk ?? '',
        'subKategori': _kategoriSub ?? '',
        'hargaBeli': _hargaBeli.text.replaceAll(RegExp(r'[^\d]'), ''),
        'hargaJual': _hargaJual.text.replaceAll(RegExp(r'[^\d]'), ''),
        'hargaJual2': _hargaJual2.text.replaceAll(RegExp(r'[^\d]'), ''),
        'stok': '0',
        'satuan': _satuan ?? '',
        'foto': _fotoPath,
      });
      if (mounted) {
        context.read<EventProvider>().refreshProduk();
        showToast(context, 'Produk berhasil disimpan');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  bool get _isMinumanForm {
    final k = (_kategoriInduk ?? '').toLowerCase();
    final s = (_kategoriSub ?? '').toLowerCase();
    return k.contains('minum') ||
        k.contains('drink') ||
        k.contains('beverage') ||
        k.contains('kopi') ||
        k.contains('coffee') ||
        k.contains('tea') ||
        k.contains('teh') ||
        k.contains('jus') ||
        s.contains('minum') ||
        s.contains('kopi') ||
        s.contains('teh');
  }

  bool get _isMakananForm {
    if (_isMinumanForm) return false;
    final k = (_kategoriInduk ?? '').toLowerCase();
    final s = (_kategoriSub ?? '').toLowerCase();
    return k.contains('makan') ||
        k.contains('food') ||
        k.contains('paket') ||
        s.contains('makan') ||
        s.contains('food');
  }

  @override
  Widget build(BuildContext context) {
    final isMinum = _isMinumanForm;
    final isMakan = _isMakananForm;

    final String labelHarga1 = isMinum
        ? 'Harga Panas (Hot)'
        : isMakan
            ? 'Harga Pake Nasi'
            : 'Harga Jual Utama';
    final String labelHarga2 = isMinum
        ? 'Harga Dingin (Ice)'
        : isMakan
            ? 'Harga Tanpa Nasi (Lauk Saja)'
            : 'Harga Varian Ke-2 (Opsional)';
    final String hintHarga2 = isMinum
        ? 'Kosongkan jika sama dengan harga Panas'
        : isMakan
            ? 'Kosongkan jika sama dengan harga Pake Nasi'
            : 'Opsional';

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Produk' : 'Tambah Produk')),
      body: _loadingOptions
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Foto Produk ──────────────────────────────────────────
                  _buildFotoPicker(),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _kode,
                          decoration: const InputDecoration(labelText: 'Kode Produk'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Kode wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          final num = Random().nextInt(9999).toString().padLeft(4, '0');
                          _kode.text = 'DLM01-$num';
                        },
                        icon: const Icon(Icons.autorenew),
                        label: const Text('Acak'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nama,
                    decoration: const InputDecoration(labelText: 'Nama Produk'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  // ── Kategori Utama ──────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _indukOptions.contains(_kategoriInduk) ? _kategoriInduk : null,
                          decoration: const InputDecoration(labelText: 'Kategori Utama'),
                          items: _indukOptions
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _kategoriInduk = v;
                            _kategoriSub = null; // reset sub saat induk berubah
                          }),
                          validator: (v) => (v == null || v.isEmpty) ? 'Kategori wajib dipilih' : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Tambah kategori utama',
                        onPressed: () => _addMasterOption('KATEGORI_INDUK'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Sub Kategori (opsional) ────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _subOptions.contains(_kategoriSub) ? _kategoriSub : null,
                          decoration: const InputDecoration(
                            labelText: 'Sub Kategori (Opsional)',
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('— Tidak ada —')),
                            ..._subOptions.map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setState(() => _kategoriSub = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Tambah sub kategori',
                        onPressed: () => _addMasterOption('KATEGORI_SUB'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Satuan ────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _satuan,
                          decoration: const InputDecoration(labelText: 'Satuan'),
                          items: _satuanOptions
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _satuan = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Tambah satuan baru',
                        onPressed: () => _addMasterOption('SATUAN'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _hargaBeli,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Harga Beli (HPP Modal)',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Input Harga 1 (Harga Utama / Panas / Pake Nasi) ───────
                  TextFormField(
                    controller: _hargaJual,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: labelHarga1,
                      prefixIcon: Icon(
                        isMinum
                            ? Icons.local_fire_department_rounded
                            : isMakan
                                ? Icons.rice_bowl_rounded
                                : Icons.sell_outlined,
                        color: isMinum
                            ? Colors.deepOrange
                            : isMakan
                                ? Colors.green
                                : AppColors.primary,
                      ),
                    ),
                    validator: (v) {
                      final n = double.tryParse(
                          (v ?? '').replaceAll(RegExp(r'[^\d.]'), ''));
                      if (n == null || n <= 0) return '$labelHarga1 wajib lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Input Harga 2 (Harga Varian / Dingin / Tanpa Nasi) ─────
                  TextFormField(
                    controller: _hargaJual2,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: labelHarga2,
                      helperText: hintHarga2,
                      prefixIcon: Icon(
                        isMinum
                            ? Icons.ac_unit_rounded
                            : isMakan
                                ? Icons.dinner_dining_rounded
                                : Icons.style_outlined,
                        color: isMinum
                            ? Colors.blue
                            : isMakan
                                ? Colors.amber.shade800
                                : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Produk'),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOTO PICKER WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildFotoPicker() {
    final bool isNetwork = _fotoPath.startsWith('http');
    final file = isNetwork ? null : _foto.getFile(_fotoPath);
    final hasFoto = isNetwork || file != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Produk',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickFoto,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasFoto ? AppColors.bg : AppColors.muted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: hasFoto
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4), width: 2)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasFoto
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      isNetwork 
                          ? CachedNetworkImage(imageUrl: _fotoPath, fit: BoxFit.cover)
                          : Image.file(file!, fit: BoxFit.cover),
                      // Overlay gelap tipis + ikon ganti
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Ganti Foto',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 44,
                          color: AppColors.muted.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap untuk pilih foto',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dari galeri perangkat',
                        style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
          ),
        ),
        if (hasFoto) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _hapusFoto,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Hapus Foto', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ],
    );
  }
}
