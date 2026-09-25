import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      showToast(context, 'Email dan password wajib diisi', isError: true);
      return;
    }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().login(email, pass);
    setState(() => _loading = false);
    if (!ok && mounted) {
      showToast(context, context.read<AuthProvider>().errorMessage ?? 'Login gagal', isError: true);
    }
  }

  Widget _buildLogoBox({IconData? iconData, String? imageAsset, required String label}) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: imageAsset != null 
              ? Image.asset(imageAsset, fit: BoxFit.cover)
              : Icon(iconData, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF1E40AF),
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1E40AF), // Match the 'Masuk Aplikasi' button color
      body: CustomPaint(
        painter: _WavePainter(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO COLLAB SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogoBox(iconData: Icons.point_of_sale_rounded, label: 'KasirKu'),
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
                          child: Container(
                            width: 3,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        _buildLogoBox(imageAsset: 'assets/images/logo.png', label: 'Warkop'),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Selamat Datang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistem kasir pintar untuk warkop modern',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // LOGIN CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Kasir',
                              labelStyle: const TextStyle(color: Colors.black54),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E40AF)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA), // Off-white
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(color: Colors.black54),
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E40AF)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF), // Blue 2
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: const Color(0xFF1E40AF).withValues(alpha: 0.5),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text(
                                    'Masuk Aplikasi',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ), // Column
              ), // ConstrainedBox
            ), // SingleChildScrollView
          ), // Center
        ), // SafeArea
      ), // CustomPaint
      ), // Scaffold
    ); // AnnotatedRegion
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.25) // Light blue motif
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.3);
    path1.quadraticBezierTo(
      size.width * 0.25, size.height * 0.25,
      size.width * 0.5, size.height * 0.35,
    );
    path1.quadraticBezierTo(
      size.width * 0.75, size.height * 0.45,
      size.width, size.height * 0.25,
    );
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.3) // Another shade of light blue motif
      ..style = PaintingStyle.fill;
    
    final path2 = Path();
    path2.moveTo(0, size.height * 0.85);
    path2.quadraticBezierTo(
      size.width * 0.3, size.height * 0.95,
      size.width * 0.6, size.height * 0.8,
    );
    path2.quadraticBezierTo(
      size.width * 0.85, size.height * 0.7,
      size.width, size.height * 0.75,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
