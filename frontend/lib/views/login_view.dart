import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isObscure = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // Theme Colors — aligned with AppColors palette
  final Color primaryColor = AppColors.primary;
  final Color backgroundDark = AppColors.backgroundDark;
  final Color inputBg = AppColors.surfaceDark;
  final Color inputBorder = AppColors.surfaceDark.withValues(alpha: 0.8);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleEmailSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email dan password harus diisi');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      // Workaround: Firebase Auth Pigeon serialization bug —
      // auth bisa berhasil di server tapi response parsing crash.
      if (FirebaseAuth.instance.currentUser == null) {
        _showError(_friendlyAuthError(e));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // Simpan profil ke Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _firestoreService.saveUserProfile(user);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      // User membatalkan dialog Google Sign-In
      if (result == null && FirebaseAuth.instance.currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      // Workaround: Firebase Auth Pigeon serialization bug
      if (FirebaseAuth.instance.currentUser == null) {
        _showError(_friendlyAuthError(e));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // Simpan profil ke Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _firestoreService.saveUserProfile(user);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  void _handleSignUp() {
      _showError('Fitur Daftar belum tersedia.');
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Masukkan email terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link reset password telah dikirim ke $email'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthError(e));
    } catch (e) {
      _showError(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menerjemahkan error Firebase Auth ke pesan ramah dalam Bahasa Indonesia.
  String _friendlyAuthError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('no user record')) {
      return 'Akun dengan email ini tidak ditemukan.';
    } else if (msg.contains('wrong-password') || msg.contains('credential is incorrect')) {
      return 'Password yang Anda masukkan salah.';
    } else if (msg.contains('invalid-email') || msg.contains('badly formatted')) {
      return 'Format email tidak valid.';
    } else if (msg.contains('user-disabled')) {
      return 'Akun ini telah dinonaktifkan.';
    } else if (msg.contains('too-many-requests')) {
      return 'Terlalu banyak percobaan. Coba lagi nanti.';
    } else if (msg.contains('email-already-in-use')) {
      return 'Email sudah terdaftar. Silakan login.';
    } else if (msg.contains('network')) {
      return 'Tidak ada koneksi internet.';
    } else if (msg.contains('invalid-credential')) {
      return 'Email atau password salah.';
    }
    return 'Login gagal. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              // Header Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_stories, color: primaryColor, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Qur'an RAG",
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sistem Tanya Jawab Al-Qur'an",
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Form Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Email", style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hint: "name@example.com",
                    icon: Icons.mail_outline,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Password", style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 14)),
                      TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: Text("Lupa kata sandi?", style: TextStyle(color: primaryColor, fontSize: 12)),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Masukkan password Anda",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Masuk", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[800])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("ATAU LANJUTKAN DENGAN", style: TextStyle(color: Colors.grey[600], fontSize: 10, letterSpacing: 1.2)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[800])),
                  ],
                ),
              ),

              // Social Login
              OutlinedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: BorderSide(color: Colors.grey[800]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: inputBg.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text("Lanjutkan dengan Google", style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Belum punya akun? ", style: TextStyle(color: Colors.grey[400])),
                  GestureDetector(
                    onTap: _isLoading ? null : _handleSignUp,
                    child: Text("Daftar", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _isObscure : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: inputBg,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ) 
          : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
    );
  }
}