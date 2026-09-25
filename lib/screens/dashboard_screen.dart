import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/event_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import '../widgets/sales_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService.instance;
  Future<DashboardSummary>? _future;
  
  late EventProvider _ev;
  int _localProdukVersion = 0;
  int _localTransaksiVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localProdukVersion = _ev.produkVersion;
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
    if (_localProdukVersion != _ev.produkVersion || 
        _localTransaksiVersion != _ev.transaksiVersion) {
      _localProdukVersion = _ev.produkVersion;
      _localTransaksiVersion = _ev.transaksiVersion;
      if (mounted) _load();
    }
  }

  void _load() {
    setState(() {
      _future = _api
          .call('dashboard.summary')
          .then((d) => DashboardSummary.fromJson(Map<String, dynamic>.from(d)))
          .catchError((e) => throw _friendlyError(e));
    });
  }

  /// Ubah error teknis (exception, timeout, dsb) jadi pesan yang gampang
  /// dimengerti pengguna, bukan sekadar melempar stack trace mentah.
  Object _friendlyError(Object e) {
    if (e is ApiException) return e;
    final msg = e.toString();
    if (msg.contains('DatabaseException') ||
        msg.contains('SqfliteFfiException')) {
      return ApiException(
          'Gagal membaca data lokal. Coba tutup dan buka ulang aplikasi.');
    }
    return ApiException('Terjadi kesalahan tak terduga saat memuat dashboard.');
  }

  Future<void> _loadAsync() async {
    _load();
    // Tunggu future selesai supaya RefreshIndicator tahu kapan berhenti berputar.
    try {
      await _future;
    } catch (_) {
      // Error sudah ditangani & ditampilkan lewat FutureBuilder di bawah.
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().me;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(

        title: const Text('Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAsync,
        child: FutureBuilder<DashboardSummary>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ErrorView(
                  message: friendlyErrorMessage(snap.error!),
                  onRetry: _load,
                ),
              );
            }
            final data = snap.data!;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth(context),
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${me?.name ?? ''} ',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, base: 18),
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ringkasan performa toko Anda',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: Responsive.fontSize(context, base: 13),
                        ),
                      ),
                      SizedBox(height: Responsive.isMobile(context) ? 14 : 18),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.statGridColumns(context),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 94,
                        ),
                        children: [
                          StatCard(
                              label: 'Transaksi Hari Ini',
                              value: rupiah(data.transHariIni),
                              icon: Icons.shopping_cart_outlined,
                              color: AppColors.primary),
                          StatCard(
                              label: 'Profit Hari Ini',
                              value: rupiah(data.profitHariIni),
                              icon: Icons.trending_up,
                              color: AppColors.success),
                          StatCard(
                              label: 'Total Transaksi',
                              value: rupiah(data.totalTrans),
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppColors.sidebarAccent),
                          StatCard(
                              label: 'Total Profit',
                              value: rupiah(data.totalProfit),
                              icon: Icons.savings_outlined,
                              color: AppColors.accent),
                          StatCard(
                            label: 'Produk Aktif',
                            value: angka(data.totalProdukAktif),
                            icon: Icons.category_outlined,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Grafik Penjualan
                      const SalesChartCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
