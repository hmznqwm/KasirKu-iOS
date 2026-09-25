import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'users_screen.dart';
import 'pengeluaran_screen.dart';
import 'supplier_screen.dart';
import 'inventaris_screen.dart';
import 'monitoring_screen.dart';
import 'moneyku_screen.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.me;
    final isAdmin = me?.isAdmin ?? false;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title:
            const Text('Profil', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: ListView(
        padding: EdgeInsets.only(
            top: 20, left: 16, right: 16, bottom: 16 + bottomInset),
        children: [
          // User Profile Card
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: Text(
                    me != null && me.name.isNotEmpty
                        ? me.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me?.name ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(me?.email ?? '-',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                      const SizedBox(height: 8),
                      StatusPill(
                        text: me?.role ?? '-',
                        bg: isAdmin
                            ? AppColors.stockOkBg
                            : AppColors.stockLowBg,
                        fg: isAdmin
                            ? AppColors.stockOkText
                            : AppColors.stockLowText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Lainnya',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.receipt_long,
            title: 'Pengeluaran / Belanja',
            subtitle: 'Catat belanja bahan pokok & lainnya',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PengeluaranScreen()));
            },
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.inventory_2_outlined,
            title: 'Data Inventaris',
            subtitle: 'Catat aset & barang inventaris',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const InventarisScreen()));
            },
          ),
          const SizedBox(height: 10),

          if (isAdmin) ...[
            const Divider(height: 30, color: AppColors.border),
            const Text(
              'Manajemen (Admin)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.business,
              title: 'Data Supplier',
              subtitle: 'Manajemen data PT/Pemasok',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SupplierScreen()));
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.monitor_heart_outlined,
              title: 'Monitoring',
              subtitle: 'Log aktivitas pengguna',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MonitoringScreen()));
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'MoneyKu',
              subtitle: 'Ringkasan uang masuk per metode',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MoneyKuScreen()));
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.people_outline,
              title: 'Manajemen User',
              subtitle: 'Kelola akun kasir & admin',
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UsersScreen()));
              },
            ),
            const SizedBox(height: 10),
          ],

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              backgroundColor: AppColors.danger.withValues(alpha: 0.1),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Keluar',
                  message: 'Yakin ingin logout dari aplikasi?');
              if (ok) await auth.logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari Akun',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
  const _MenuTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

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
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
