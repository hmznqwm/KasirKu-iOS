import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';

class CheckoutResultScreen extends StatefulWidget {
  final CheckoutResult result;
  const CheckoutResultScreen({super.key, required this.result});

  @override
  State<CheckoutResultScreen> createState() => _CheckoutResultScreenState();
}

class _CheckoutResultScreenState extends State<CheckoutResultScreen> {
  PaperSize _paperSize = PaperSize.mm58;
  bool _printing = false;

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      await PrintService.printReceipt(context, widget.result, paperSize: _paperSize);
    } catch (e) {
      if (mounted) {
        showToast(context, friendlyErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Struk Transaksi'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 640,
          child: Padding(
            padding: padding,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.stockOkBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 38),
                ),
                const SizedBox(height: 12),
                Text(
                  'Transaksi Berhasil',
                  style: TextStyle(fontSize: Responsive.fontSize(context, base: 18), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(result.invoice, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(context, 'Kasir', result.kasirName),
                      _row(context, 'Waktu', tanggalIndo(result.createdAt)),
                      _row(context, 'Metode', result.metode),
                      const Divider(height: 24),
                      // ListView.separated di dalam Column non-scrollable
                      // (shrinkWrap) supaya daftar item panjang tetap rapi
                      // dan tidak overflow, alih-alih spread biasa.
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: result.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, i) {
                          final it = result.items[i];
                          final nama = (it['nama'] ?? '').toString();
                          final qty = it['qty'];
                          final subtotal = it['subtotal'];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '$nama x${(qty is num) ? qty.toStringAsFixed(0) : qty}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rupiah((subtotal is num) ? subtotal : 0),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _row(context, 'Subtotal', rupiah(result.subtotal)),
                      _row(context, 'Diskon', rupiah(result.diskon)),
                      _row(context, 'Total', rupiah(result.total), bold: true),
                      _row(context, 'Bayar', rupiah(result.bayar)),
                      _row(context, 'Kembalian', rupiah(result.kembalian), bold: true, color: AppColors.success),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.print_outlined, size: 18, color: AppColors.muted),
                          SizedBox(width: 6),
                          Text('Ukuran Kertas Printer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _paperChip(PaperSize.mm58, '58mm'),
                          _paperChip(PaperSize.mm80, '80mm'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Tombol cetak & selesai bertumpuk vertikal di HP sempit,
                // sejajar di layar lebar (tablet/landscape) — mirip flex-col
                // sm:flex-row di web.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final printButton = OutlinedButton.icon(
                      onPressed: _printing ? null : _handlePrint,
                      icon: _printing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(_printing ? 'Mengirim...' : 'Cetak Struk'),
                    );
                    final doneButton = ElevatedButton(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      child: const Text('Selesai'),
                    );

                    if (constraints.maxWidth < 360) {
                      // HP sangat sempit: tumpuk vertikal supaya label tombol
                      // ("Mengirim...", "Cetak Struk") tidak terpotong.
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: printButton),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: doneButton),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: printButton),
                        const SizedBox(width: 12),
                        Expanded(child: doneButton),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paperChip(PaperSize size, String label) {
    final selected = _paperSize == size;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _paperSize = size),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.text,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 13,
                color: color ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
