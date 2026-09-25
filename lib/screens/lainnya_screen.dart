import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pengeluaran_screen.dart';
import 'inventaris_screen.dart';

class LainnyaScreen extends StatelessWidget {
  const LainnyaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.me;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Lainnya', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: Text(
                    me != null && me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me?.name ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(me?.email ?? '-', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      const SizedBox(height: 8),
                      StatusPill(
                        text: me?.role ?? '-',
                        bg: AppColors.stockLowBg,
                        fg: AppColors.stockLowText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Lainnya',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.receipt_long,
            title: 'Pengeluaran / Belanja',
            subtitle: 'Catat belanja bahan pokok & lainnya',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PengeluaranScreen()));
            },
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.inventory_2_outlined,
            title: 'Data Inventaris',
            subtitle: 'Catat aset & barang inventaris',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InventarisScreen()));
            },
          ),
          const SizedBox(height: 30),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              backgroundColor: AppColors.danger.withValues(alpha: 0.1),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Keluar', message: 'Yakin ingin logout dari aplikasi?');
              if (ok) await auth.logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SectionCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
