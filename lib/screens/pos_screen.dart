import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/foto_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import 'package:provider/provider.dart';
import '../services/event_provider.dart';
import 'checkout_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();
  Future<List<Produk>>? _future;
  final Map<String, CartItem> _cart = {};
  String _selectedKategori = '';    // Kategori Utama, '' = semua
  String _selectedSubKategori = ''; // Sub Kategori, '' = semua sub
  bool _showImage = true;
  
  late EventProvider _ev;
  int _localProdukVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localProdukVersion = _ev.produkVersion;
    _ev.addListener(_onEvent);
    _loadPrefs();
    _load();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('pos_show_image')) {
      setState(() {
        _showImage = prefs.getBool('pos_show_image') ?? true;
      });
    }
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
      _future = _api.call('produk.list', {'q': q ?? ''}).then(
          (d) => (d as List).map((e) => Produk.fromJson(Map<String, dynamic>.from(e))).toList());
    });
  }

  bool _isMinuman(Produk p) {
    final k = p.kategori.toLowerCase();
    final s = p.subKategori.toLowerCase();
    return k.contains('minum') ||
        k.contains('drink') ||
        k.contains('beverage') ||
        k.contains('kopi') ||
        k.contains('coffee') ||
        k.contains('tea') ||
        k.contains('teh') ||
        k.contains('jus') ||
        k.contains('juice') ||
        k.contains('boba') ||
        s.contains('minum') ||
        s.contains('drink') ||
        s.contains('kopi') ||
        s.contains('teh');
  }

  bool _isMakanan(Produk p) {
    if (_isMinuman(p)) return false;
    final k = p.kategori.toLowerCase();
    final s = p.subKategori.toLowerCase();
    return k.contains('makan') ||
        k.contains('food') ||
        k.contains('paket') ||
        k.contains('resto') ||
        k.contains('dapur') ||
        s.contains('makan') ||
        s.contains('food') ||
        s.contains('paket');
  }

  int _getCartQtyForProduct(String produkId) {
    return _cart.values
        .where((c) => c.produk.id == produkId)
        .fold(0, (sum, c) => sum + c.qty.toInt());
  }

  void _onProductTap(Produk p) {
    if (_isMinuman(p)) {
      _openVariantModal(p, type: _VariantType.minuman);
    } else if (_isMakanan(p)) {
      _openVariantModal(p, type: _VariantType.makanan);
    } else {
      _addToCart(p);
    }
  }

  void _addToCart(Produk p, {String varian = '', double qty = 1, double? harga}) {
    setState(() {
      final key = varian.isNotEmpty ? '${p.id}__$varian' : p.id;
      final existing = _cart[key];
      if (existing != null) {
        existing.qty += qty;
      } else {
        _cart[key] = CartItem(produk: p, varian: varian, qty: qty, customHarga: harga);
      }
    });
  }

  void _openVariantModal(Produk p, {required _VariantType type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantPickerSheet(
        produk: p,
        type: type,
        onConfirm: (varian, qty, harga) {
          _addToCart(p, varian: varian, qty: qty, harga: harga);
        },
      ),
    );
  }

  double get _cartTotal => _cart.values.fold(0, (a, b) => a + b.subtotal);
  int get _cartCount => _cart.values.length;

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CartSheet(
        cart: _cart,
        onChanged: () => setState(() {}),
        onCheckoutDone: () {
          setState(() => _cart.clear());
          _load(q: _searchCtrl.text);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: const Text('Kasir'),
      ),
      floatingActionButton: _cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCart,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              extendedPadding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: Badge(
                backgroundColor: AppColors.danger,
                textColor: Colors.white,
                label: Text('$_cartCount', style: const TextStyle(fontWeight: FontWeight.w700)),
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              ),
              label: Text(
                rupiah(_cartTotal),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari produk untuk dijual...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); }),
              ),
              onSubmitted: (_) => setState(() {}),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // ── Filter Kategori 2 tingkat ──────────────────────────────────────
          FutureBuilder<List<Produk>>(
            future: _future,
            builder: (context, snap) {
              final list = snap.data ?? [];
              final aktif = list.where((p) => p.status.toUpperCase() == 'AKTIF').toList();

              // Kumpulkan semua kategori induk unik
              final indukSet = aktif
                  .map((p) => p.kategori)
                  .where((k) => k.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              // Sub kategori berdasarkan induk yg dipilih
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
              return _DualKategoriBar(
                indukList: indukSet,
                subList: subSet,
                selectedInduk: _selectedKategori,
                selectedSub: _selectedSubKategori,
                onIndukSelected: (k) => setState(() {
                  _selectedKategori = k;
                  _selectedSubKategori = '';
                }),
                onSubSelected: (s) => setState(() => _selectedSubKategori = s),
                showImage: _showImage,
                onToggleImage: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final newVal = !_showImage;
                  await prefs.setBool('pos_show_image', newVal);
                  setState(() => _showImage = newVal);
                },
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
                  final all = (snap.data ?? []).where((p) => p.status.toUpperCase() == 'AKTIF').toList();
                  // Filter 2 level (client-side)
                  final list = all.where((p) {
                    if (_selectedKategori.isNotEmpty) {
                      if (p.kategori != _selectedKategori) return false;
                    }
                    if (_selectedSubKategori.isNotEmpty) {
                      if (p.subKategori != _selectedSubKategori) return false;
                    }
                    return true;
                  }).toList();
                  // Filter berdasarkan teks pencarian (client-side)
                  final q = _searchCtrl.text.toLowerCase();
                  final filtered = q.isEmpty
                      ? list
                      : list.where((p) =>
                          p.nama.toLowerCase().contains(q) ||
                          p.kode.toLowerCase().contains(q)).toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [EmptyState(message: 'Produk tidak ditemukan', icon: Icons.search_off)],
                    );
                  }
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.value(context, mobile: 2, tablet: 4, desktop: 5),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: _showImage 
                          ? Responsive.value(context, mobile: 0.72, tablet: 0.8)
                          : Responsive.value(context, mobile: 1.0, tablet: 1.1),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final inCart = _getCartQtyForProduct(p.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _onProductTap(p),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: inCart > 0 ? Border.all(color: AppColors.primary, width: 1.5) : null,
                            boxShadow: inCart == 0 ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))
                            ] : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showImage) ...[
                                Expanded(
                                  child: _PosProductImage(fotoPath: p.foto),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(p.nama,
                                  maxLines: _showImage ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: _showImage ? 13 : 16)),
                              if (!_showImage) const Spacer(),
                              if (_showImage) const SizedBox(height: 4),
                              Text(rupiah(p.hargaJual),
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: _showImage ? 13.5 : 16.5)),
                              if (inCart > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            final matchingKeys = _cart.keys.where((k) => _cart[k]!.produk.id == p.id).toList();
                                            if (matchingKeys.isNotEmpty) {
                                              final lastKey = matchingKeys.last;
                                              if (_cart[lastKey]!.qty <= 1) {
                                                _cart.remove(lastKey);
                                              } else {
                                                _cart[lastKey]!.qty -= 1;
                                              }
                                            }
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          child: Icon(Icons.remove, size: 18, color: AppColors.primary),
                                        ),
                                      ),
                                      Text(
                                        inCart.toString(),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _onProductTap(p),
                                        behavior: HitTestBehavior.opaque,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          child: Icon(Icons.add, size: 18, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
// Dual chip bar filter kategori 2 tingkat (Induk + Sub)
// ---------------------------------------------------------------------------

class _DualKategoriBar extends StatelessWidget {
  final List<String> indukList;
  final List<String> subList;
  final String selectedInduk;
  final String selectedSub;
  final ValueChanged<String> onIndukSelected;
  final ValueChanged<String> onSubSelected;
  final bool showImage;
  final VoidCallback onToggleImage;

  const _DualKategoriBar({
    required this.indukList,
    required this.subList,
    required this.selectedInduk,
    required this.selectedSub,
    required this.onIndukSelected,
    required this.onSubSelected,
    required this.showImage,
    required this.onToggleImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Baris 1: Toggle Gambar + Kategori Utama
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // Tombol Toggle Image
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: onToggleImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        showImage ? Icons.image_outlined : Icons.image_not_supported_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                _chip('', 'Semua', selectedInduk, onIndukSelected, isPrimary: true),
                ...indukList.map((k) => _chip(k, k, selectedInduk, onIndukSelected, isPrimary: true)),
              ],
            ),
          ),
        ),
        // Baris 2: Sub Kategori (hanya muncul jika induk dipilih dan ada sub)
        if (selectedInduk.isNotEmpty && subList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _chip('', 'Semua $selectedInduk', selectedSub, onSubSelected, isPrimary: false),
                  ...subList.map((s) => _chip(s, s, selectedSub, onSubSelected, isPrimary: false)),
                ],
              ),
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
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: AppColors.border),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet keranjang belanja + form checkout (bayar, diskon, metode).
class CartSheet extends StatefulWidget {
  final Map<String, CartItem> cart;
  final VoidCallback onChanged;
  final VoidCallback onCheckoutDone;

  const CartSheet({super.key, required this.cart, required this.onChanged, required this.onCheckoutDone});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final _api = ApiService.instance;
  final _bayarCtrl = TextEditingController();
  final _diskonCtrl = TextEditingController(text: '0');
  String _metode = 'CASH';
  bool _processing = false;

  double get _subtotal => widget.cart.values.fold(0, (a, b) => a + b.subtotal);
  double get _diskon => double.tryParse(_diskonCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  double get _total => (_subtotal - _diskon).clamp(0, double.infinity);
  double get _bayar => double.tryParse(_bayarCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  double get _kembalian => (_bayar - _total).clamp(0, double.infinity);

  Future<void> _checkout() async {
    if (widget.cart.isEmpty) return;
    if (_total <= 0) {
      showToast(context, 'Total transaksi tidak valid', isError: true);
      return;
    }
    if (_bayar < _total) {
      showToast(context, 'Nominal bayar kurang', isError: true);
      return;
    }
    setState(() => _processing = true);
    try {
      final items = widget.cart.values.map((c) => {
        'produkId': c.produk.id,
        'qty': c.qty,
        'nama': c.displayName,
        'varian': c.varian,
        'harga': c.hargaItem,
      }).toList();
      final data = await _api.call('transaksi.checkout', {
        'items': items,
        'bayar': _bayar,
        'diskon': _diskon,
        'metode': _metode,
      });
      final result = CheckoutResult.fromJson(Map<String, dynamic>.from(data));
      if (mounted) context.read<EventProvider>().refreshTransaksi();
      widget.onCheckoutDone();
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutResultScreen(result: result)));
      }
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cart.values.toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    const Text('Keranjang Belanja', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (items.isEmpty)
                      const EmptyState(message: 'Keranjang masih kosong', icon: Icons.shopping_cart_outlined)
                    else
                      ...items.map((c) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.produk.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                        if (c.varian.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          _VariantBadge(varian: c.varian),
                                        ],
                                        const SizedBox(height: 3),
                                        Text(rupiah(c.hargaItem), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () => setState(() {
                                      if (c.qty <= 1) {
                                        widget.cart.remove(c.cartKey);
                                      } else {
                                        c.qty -= 1;
                                      }
                                      widget.onChanged();
                                    }),
                                  ),
                                  Text(c.qty.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () => setState(() {
                                      c.qty += 1;
                                      widget.onChanged();
                                    }),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(rupiah(c.subtotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          )),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SectionCard(
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Subtotal', style: TextStyle(color: AppColors.muted)),
                              Text(rupiah(_subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _diskonCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: const InputDecoration(labelText: 'Diskon (Rp)'),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            const Align(alignment: Alignment.centerLeft, child: Text('Metode Pembayaran', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _PaymentMethodBtn(value: 'CASH', icon: Icons.payments_outlined, selected: _metode, onSelect: (v) => setState(() => _metode = v))),
                                const SizedBox(width: 8),
                                Expanded(child: _PaymentMethodBtn(value: 'QRIS', icon: Icons.qr_code_2, selected: _metode, onSelect: (v) => setState(() => _metode = v))),
                                const SizedBox(width: 8),
                                Expanded(child: _PaymentMethodBtn(value: 'DEBIT', icon: Icons.credit_card_outlined, selected: _metode, onSelect: (v) => setState(() => _metode = v))),
                                const SizedBox(width: 8),
                                Expanded(child: _PaymentMethodBtn(value: 'TRANSFER', icon: Icons.account_balance_outlined, selected: _metode, onSelect: (v) => setState(() => _metode = v))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _bayarCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: const InputDecoration(labelText: 'Jumlah Bayar (Rp)'),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _QuickNominalBtn(label: 'Pas', onTap: () { _bayarCtrl.text = angka(_total.toInt()); setState((){}); })),
                                const SizedBox(width: 8),
                                Expanded(child: _QuickNominalBtn(label: '20K', onTap: () { _bayarCtrl.text = angka(20000); setState((){}); })),
                                const SizedBox(width: 8),
                                Expanded(child: _QuickNominalBtn(label: '50K', onTap: () { _bayarCtrl.text = angka(50000); setState((){}); })),
                                const SizedBox(width: 8),
                                Expanded(child: _QuickNominalBtn(label: '100K', onTap: () { _bayarCtrl.text = angka(100000); setState((){}); })),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text(rupiah(_total),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
                            ]),
                            const SizedBox(height: 6),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Kembalian', style: TextStyle(color: AppColors.muted)),
                              Text(rupiah(_kembalian), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _processing ? null : _checkout,
                        child: _processing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Proses Pembayaran'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentMethodBtn extends StatelessWidget {
  final String value;
  final IconData icon;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PaymentMethodBtn({required this.value, required this.icon, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 1.5 : 1),
        ),
        child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.muted, size: 24),
      ),
    );
  }
}

class _QuickNominalBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickNominalBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnail foto produk untuk layar Kasir (POS)
// ---------------------------------------------------------------------------

class _PosProductImage extends StatelessWidget {
  final String fotoPath;
  const _PosProductImage({required this.fotoPath});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = const Center(
      child: Icon(Icons.image_outlined, size: 28, color: AppColors.border),
    );
    
    if (fotoPath.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: fotoPath, 
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: Icon(Icons.image_outlined, size: 28, color: AppColors.border),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.image_not_supported, size: 28, color: AppColors.border),
        ),
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
        width: double.infinity,
        color: AppColors.bg,
        child: imageWidget,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Varian Item Keranjang
// ---------------------------------------------------------------------------

class _VariantBadge extends StatelessWidget {
  final String varian;
  const _VariantBadge({required this.varian});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    final label = varian;

    final vLower = varian.toLowerCase();
    if (vLower.contains('panas') || vLower.contains('hot')) {
      bg = Colors.deepOrange.withValues(alpha: 0.12);
      fg = Colors.deepOrange.shade800;
      icon = Icons.local_fire_department_rounded;
    } else if (vLower.contains('dingin') || vLower.contains('ice')) {
      bg = Colors.blue.withValues(alpha: 0.12);
      fg = Colors.blue.shade800;
      icon = Icons.ac_unit_rounded;
    } else if (vLower.contains('tanpa nasi')) {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber.shade900;
      icon = Icons.no_meals_rounded;
    } else if (vLower.contains('nasi')) {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = Colors.green.shade800;
      icon = Icons.rice_bowl_rounded;
    } else {
      bg = AppColors.primary.withValues(alpha: 0.1);
      fg = AppColors.primary;
      icon = Icons.tune_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog / Bottom Sheet Pilihan Varian (Minuman Hot/Ice & Makanan Nasi/Tanpa Nasi)
// ---------------------------------------------------------------------------

enum _VariantType { minuman, makanan }

class _VariantPickerSheet extends StatefulWidget {
  final Produk produk;
  final _VariantType type;
  final Function(String varian, double qty, double harga) onConfirm;

  const _VariantPickerSheet({
    required this.produk,
    required this.type,
    required this.onConfirm,
  });

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  late String _selectedVariant;
  double _qty = 1;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.type == _VariantType.minuman ? 'Dingin' : 'Pake Nasi';
  }

  double get _hargaOpsi1 => widget.produk.hargaJual;
  double get _hargaOpsi2 =>
      widget.produk.hargaJual2 > 0 ? widget.produk.hargaJual2 : widget.produk.hargaJual;

  double get _currentPrice {
    if (widget.type == _VariantType.minuman) {
      return _selectedVariant == 'Panas' ? _hargaOpsi1 : _hargaOpsi2;
    } else {
      return _selectedVariant == 'Pake Nasi' ? _hargaOpsi1 : _hargaOpsi2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMinuman = widget.type == _VariantType.minuman;
    final title = isMinuman ? 'Pilihan Suhu Minuman' : 'Porsi Nasi / Lauk';
    final subtitle = isMinuman
        ? 'Pilih varian suhu untuk ${widget.produk.nama}'
        : 'Pilih opsi nasi untuk ${widget.produk.nama}';

    final harga1 = _hargaOpsi1;
    final harga2 = _hargaOpsi2;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Info Produk
          Row(
            children: [
              if (widget.produk.foto.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: _PosProductImage(fotoPath: widget.produk.foto),
                  ),
                )
              else
                _defaultIcon(isMinuman),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.produk.nama,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rupiah(_currentPrice),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.card),
              ),
            ],
          ),

          const Divider(height: 28),

          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),

          // Option cards
          if (isMinuman) ...[
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    title: 'Panas (Hot)',
                    subtitle: rupiah(harga1),
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.deepOrange,
                    isSelected: _selectedVariant == 'Panas',
                    onTap: () => setState(() => _selectedVariant = 'Panas'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    title: 'Dingin (Ice)',
                    subtitle: rupiah(harga2),
                    icon: Icons.ac_unit_rounded,
                    color: Colors.blue,
                    isSelected: _selectedVariant == 'Dingin',
                    onTap: () => setState(() => _selectedVariant = 'Dingin'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    title: 'Pake Nasi',
                    subtitle: rupiah(harga1),
                    icon: Icons.rice_bowl_rounded,
                    color: Colors.green,
                    isSelected: _selectedVariant == 'Pake Nasi',
                    onTap: () => setState(() => _selectedVariant = 'Pake Nasi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    title: 'Tanpa Nasi',
                    subtitle: rupiah(harga2),
                    icon: Icons.dinner_dining_rounded,
                    color: Colors.amber.shade800,
                    isSelected: _selectedVariant == 'Tanpa Nasi',
                    onTap: () => setState(() => _selectedVariant = 'Tanpa Nasi'),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Stepper Jumlah Porsi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jumlah Porsi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _qty <= 1 ? null : () => setState(() => _qty -= 1),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      child: Text(
                        _qty.toInt().toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => setState(() => _qty += 1),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Tombol Konfirmasi
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                widget.onConfirm(_selectedVariant, _qty, _currentPrice);
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tambahkan • ${rupiah(_currentPrice * _qty)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultIcon(bool isMinuman) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isMinuman ? Icons.local_cafe_rounded : Icons.restaurant_rounded,
        color: AppColors.primary,
        size: 28,
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: isSelected ? color : AppColors.muted, size: 22),
                ),
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isSelected ? color : AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

