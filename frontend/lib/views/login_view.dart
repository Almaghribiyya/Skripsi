import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../viewmodels/chat_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Step 1 = email, Step 2 = password
  int _step = 1;
  bool _isObscure = true;
  bool _isLoading = false;
  String _emailError = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

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

  // ─── Helpers ──────────────────────────────────────────────────────

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

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email);
  }

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
    } else if (msg.contains('weak-password')) {
      return 'Password terlalu lemah. Minimal 6 karakter.';
    } else if (msg.contains('network')) {
      return 'Tidak ada koneksi internet.';
    } else if (msg.contains('invalid-credential')) {
      return 'Email atau password salah.';
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  // ─── Step 1: Validasi Email ───────────────────────────────────────

  void _handleEmailContinue() {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Email tidak boleh kosong');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Format email tidak valid');
      return;
    }

    setState(() {
      _emailError = '';
      _step = 2;
    });
  }

  // ─── Step 2: Sign In / Sign Up ────────────────────────────────────

  Future<void> _handleSubmitPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      _showError('Password tidak boleh kosong');
      return;
    }
    if (password.length < 6) {
      _showError('Password minimal 6 karakter');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Coba login terlebih dahulu
      await _authService.signInWithEmail(email, password);
    } catch (signInError) {
      final msg = signInError.toString().toLowerCase();
      // Firebase modern: 'invalid-credential' mencakup user-not-found & wrong-password
      final isNotFound = msg.contains('user-not-found') ||
          msg.contains('no user record') ||
          msg.contains('invalid-credential');

      if (isNotFound) {
        // Akun mungkin belum ada → coba daftarkan otomatis
        try {
          await _authService.signUpWithEmail(email, password);
        } catch (signUpError) {
          if (FirebaseAuth.instance.currentUser == null) {
            final signUpMsg = signUpError.toString().toLowerCase();
            // Jika sign-up gagal karena email sudah ada → password memang salah
            if (signUpMsg.contains('email-already-in-use')) {
              _showError('Password yang Anda masukkan salah.');
            } else {
              _showError(_friendlyAuthError(signUpError));
            }
            if (mounted) setState(() => _isLoading = false);
            return;
          }
        }
      } else if (FirebaseAuth.instance.currentUser == null) {
        _showError(_friendlyAuthError(signInError));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.saveUserProfile(user);
      if (mounted) {
        await context.read<ChatViewModel>().loadUserSessions(user.uid);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  // ─── Google Sign In ───────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null && FirebaseAuth.instance.currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) {
        _showError(_friendlyAuthError(e));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.saveUserProfile(user);
      if (mounted) {
        await context.read<ChatViewModel>().loadUserSessions(user.uid);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 40),
              // Form — step 1 or step 2
              _step == 1 ? _buildEmailStep() : _buildPasswordStep(),
              // Divider
              _buildDivider(),
              // Google Sign In
              _buildGoogleButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
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
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        ),
      ],
    );
  }

  // ─── Step 1: Email ────────────────────────────────────────────────

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Email", style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => _handleEmailContinue(),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            hintText: "name@example.com",
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[400], size: 20),
            errorText: _emailError.isNotEmpty ? _emailError : null,
            errorStyle: const TextStyle(color: Colors.redAccent),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _emailError.isNotEmpty ? Colors.redAccent : inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _emailError.isNotEmpty ? Colors.redAccent : primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          onChanged: (_) {
            if (_emailError.isNotEmpty) setState(() => _emailError = '');
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _handleEmailContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "Lanjutkan",
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Password ─────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email preview (bisa klik untuk kembali ke step 1)
        GestureDetector(
          onTap: () => setState(() {
            _step = 1;
            _passwordController.clear();
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: inputBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline, color: Colors.grey[400], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emailController.text.trim(),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.edit, color: primaryColor, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("Password", style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _isObscure,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSubmitPassword(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            hintText: "Masukkan password Anda",
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
            suffixIcon: IconButton(
              icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Jika belum memiliki akun, akun baru akan dibuat otomatis.',
          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmitPassword,
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
                : Text(
                    "Masuk / Daftar",
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Divider ──────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[800])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("ATAU", style: TextStyle(color: Colors.grey[600], fontSize: 10, letterSpacing: 1.2)),
          ),
          Expanded(child: Divider(color: Colors.grey[800])),
        ],
      ),
    );
  }

  // ─── Google Button ────────────────────────────────────────────────

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        side: BorderSide(color: Colors.grey[800]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: inputBg.withValues(alpha: 0.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Text("Masuk dengan Google", style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}