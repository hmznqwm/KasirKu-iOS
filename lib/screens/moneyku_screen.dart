import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../utils/responsive.dart';

class MoneyKuScreen extends StatefulWidget {
  const MoneyKuScreen({super.key});

  @override
  State<MoneyKuScreen> createState() => _MoneyKuScreenState();
}

class _MoneyKuScreenState extends State<MoneyKuScreen> {
  final _api = ApiService.instance;
  bool _loading = true;
  DateTimeRange? _dateRange;

  double _cash = 0;
  double _qris = 0;
  double _kredit = 0;
  double _transfer = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = <String, dynamic>{};
      if (_dateRange != null) {
        p['tglMulai'] = _dateRange!.start.toIso8601String().split('T').first;
        p['tglSelesai'] = _dateRange!.end.toIso8601String().split('T').first;
      }

      final data = await _api.call('moneyku.summary', p);
      _cash = (data['cash'] as num?)?.toDouble() ?? 0;
      _qris = (data['qris'] as num?)?.toDouble() ?? 0;
      _kredit = (data['kredit'] as num?)?.toDouble() ?? 0;
      _transfer = (data['transfer'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (res != null) {
      setState(() => _dateRange = res);
      _load();
    }
  }

  Widget _buildCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            rupiah(amount),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);
    final isTab = Responsive.isTablet(context);
    final isDesk = Responsive.isDesktop(context);

    int crossCount = 1;
    double ratio = 2.8;
    if (isDesk) {
      crossCount = 4;
      ratio = 1.3;
    } else if (isTab) {
      crossCount = 2;
      ratio = 1.8;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyKu'),
      ),
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: padding,
                children: [
                  // ── Header + filter ──
                  const Text(
                    'Ringkasan Pemasukan',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nominal uang masuk dari transaksi kasir\n(tidak termasuk belanja/pengeluaran)',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // ── Date filter row ──
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Periode Pemasukan',
                                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dateRange == null
                                      ? 'Semua Waktu'
                                      : '${tanggalBulan(_dateRange!.start.toIso8601String())} – ${tanggalBulan(_dateRange!.end.toIso8601String())}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_dateRange != null)
                            GestureDetector(
                              onTap: () {
                                setState(() => _dateRange = null);
                                _load();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(right: 8), // Tetap ada sedikit margin kanan jika icon arrow dihilangkan
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.red.shade700, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 4 Cards Grid ──
                  GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: ratio,
                    children: [
                      _buildCard('Cash', _cash, Icons.payments_outlined, Colors.green.shade700),
                      _buildCard('QRIS', _qris, Icons.qr_code_2, Colors.blue.shade700),
                      _buildCard('Kredit', _kredit, Icons.credit_card_outlined, Colors.orange.shade700),
                      _buildCard('Transfer', _transfer, Icons.account_balance_outlined, Colors.purple.shade700),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Total ──
                  SectionCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Pemasukan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                          rupiah(_cash + _qris + _kredit + _transfer),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
