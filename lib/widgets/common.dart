import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 150;
        final theme = Theme.of(context);
        return SectionCard(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 7 : 10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: compact ? 17 : 22),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: compact ? 11 : 12.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: compact ? 14 : 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                      ),
                    ),
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

class StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const StatusPill({super.key, required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner alert merah/kuning/hijau untuk ditaruh di atas form atau daftar,
/// dipakai saat submit gagal, ada peringatan stok, dsb. Ini melengkapi
/// [ErrorView] (yang menggantikan seluruh isi halaman) untuk kasus di mana
/// kita masih ingin menampilkan form/isian di baliknya.
class AlertBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final IconData icon;
  final Color bg;
  final Color fg;

  const AlertBanner._({
    required this.message,
    required this.icon,
    required this.bg,
    required this.fg,
    this.onDismiss,
  });

  factory AlertBanner.error(String message, {VoidCallback? onDismiss}) => AlertBanner._(
        message: message,
        icon: Icons.error_outline,
        bg: AppColors.stockOutBg,
        fg: AppColors.danger,
        onDismiss: onDismiss,
      );

  factory AlertBanner.warning(String message, {VoidCallback? onDismiss}) => AlertBanner._(
        message: message,
        icon: Icons.warning_amber_rounded,
        bg: AppColors.stockLowBg,
        fg: AppColors.warning,
        onDismiss: onDismiss,
      );

  factory AlertBanner.success(String message, {VoidCallback? onDismiss}) => AlertBanner._(
        message: message,
        icon: Icons.check_circle_outline,
        bg: AppColors.stockOkBg,
        fg: AppColors.success,
        onDismiss: onDismiss,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, color: fg, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

/// Teks error kecil di bawah field form (validasi inline), dipakai bersamaan
/// dengan TextFormField.validator atau ditaruh manual di bawah input custom.
class InlineFieldError extends StatelessWidget {
  final String? message;
  const InlineFieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ambil pesan yang enak dibaca dari sebuah error/exception apa pun.
/// - ApiException / Exception biasa -> pakai toString() (sudah bersih di app ini)
/// - Selain itu -> pesan generik supaya tidak menampilkan stack trace ke user.
String friendlyErrorMessage(Object error) {
  final msg = error.toString();
  // Buang prefix teknis seperti "Exception: " kalau ada terbawa dari luar.
  final cleaned = msg.startsWith('Exception: ') ? msg.substring('Exception: '.length) : msg;
  if (cleaned.trim().isEmpty) return 'Terjadi kesalahan yang tidak diketahui.';
  return cleaned;
}

void showToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.text,
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ya, Lanjutkan'),
        ),
      ],
    ),
  );
  return res ?? false;
}
