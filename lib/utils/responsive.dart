import 'package:flutter/material.dart';

/// Helper breakpoint terpusat supaya seluruh layar (Dashboard, POS, Produk,
/// Riwayat, dll) konsisten dalam menentukan kapan harus tampil sebagai
/// "mobile", "tablet", atau "desktop/landscape lebar".
///
/// Dipakai seperti CSS media query di web:
///   Responsive.isMobile(context)   -> lebar < 600  (HP portrait)
///   Responsive.isTablet(context)   -> 600 - 1024    (HP landscape / tablet kecil)
///   Responsive.isDesktop(context)  -> >= 1024       (tablet besar / desktop)
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => widthOf(context) < mobileMax;
  static bool isTablet(BuildContext context) => widthOf(context) >= mobileMax && widthOf(context) < tabletMax;
  static bool isDesktop(BuildContext context) => widthOf(context) >= tabletMax;

  /// Pilih nilai sesuai lebar layar saat ini. `tablet`/`desktop` opsional;
  /// jika tidak diisi maka akan jatuh ke nilai yang lebih kecil di bawahnya.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final w = widthOf(context);
    if (w >= tabletMax) return desktop ?? tablet ?? mobile;
    if (w >= mobileMax) return tablet ?? mobile;
    return mobile;
  }

  /// Jumlah kolom grid statistik dashboard: 1 di HP, 2 di tablet, 3/4 di desktop
  static int statGridColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= tabletMax) return 4;
    if (w >= mobileMax) return 2;
    return 1;
  }

  /// Rasio lebar:tinggi kartu statistik supaya teks tidak overflow saat kolom
  /// bertambah banyak (kartu makin sempit -> perlu makin "gemuk" rasionya turun).
  static double statCardAspectRatio(BuildContext context) {
    final cols = statGridColumns(context);
    if (cols == 1) return 3.5; // Lebar penuh di HP
    if (cols >= 4) return 1.35;
    if (cols == 3) return 1.45;
    return isMobile(context) ? 1.55 : 1.75; // Cols 2
  }

  /// Padding horizontal halaman: rapat di HP kecil, lega di tablet/desktop.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = widthOf(context);
    if (w >= tabletMax) return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    if (w >= mobileMax) return const EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 14);
  }

  /// Batasi lebar konten maksimum di layar sangat lebar (desktop/tablet besar)
  /// supaya kartu tidak melebar tak berbentuk, mirip `max-w-screen-lg mx-auto`.
  static double maxContentWidth(BuildContext context) => 900;

  /// Ukuran font judul/label yang menyusut di layar sempit.
  static double fontSize(BuildContext context, {required double base, double min = 11}) {
    final w = widthOf(context);
    if (w < 340) return (base - 1.5).clamp(min, base);
    return base;
  }
}

/// Wrapper agar konten halaman otomatis center + dibatasi lebar maksimum di
/// layar lebar (tablet landscape / desktop), tapi full-width apa adanya di HP.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 900});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
