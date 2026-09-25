import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'produk_screen.dart';
import 'riwayat_screen.dart';
import 'lainnya_screen.dart';
import 'profil_screen.dart'; // Add ProfilScreen

/// Shell utama setelah login: bottom navigation bar dengan 5 tab utama,
/// mirip struktur sidebar menu pada versi web (Dashboard, Kasir, Produk,
/// Riwayat, Profil/Lainnya).
final GlobalKey<ScaffoldState> homeShellKey = GlobalKey<ScaffoldState>();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.me?.isAdmin ?? false;

    final pages = isAdmin
        ? const [
            DashboardScreen(),
            PosScreen(),
            ProdukScreen(),
            RiwayatScreen(),
            ProfilScreen(),
          ]
        : const [
            PosScreen(),
            ProdukScreen(),
            RiwayatScreen(),
            LainnyaScreen(),
          ];

    return Scaffold(
      key: homeShellKey,
      body: pages[_index],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.muted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
                color: selected ? AppColors.primary : AppColors.muted);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: isAdmin
              ? const [
                  NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Dashboard'),
                  NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale),
                      label: 'Kasir'),
                  NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Produk'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Riwayat'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profil'),
                ]
              : const [
                  NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale),
                      label: 'Kasir'),
                  NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Produk'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Riwayat'),
                  NavigationDestination(
                      icon: Icon(Icons.menu_outlined),
                      selectedIcon: Icon(Icons.menu),
                      label: 'Lainnya'),
                ],
        ),
      ),
    );
  }
}

/// Header kecil yang dipakai berulang di beberapa screen untuk menampilkan
/// info user yang sedang login.
class UserBadge extends StatelessWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().me;
    if (me == null) return const SizedBox.shrink();
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
