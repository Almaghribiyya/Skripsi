import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'widgets/welcome/logo_glow_widget.dart';
import 'widgets/welcome/title_section.dart';
import 'widgets/welcome/image_grid_decoration.dart';
import 'widgets/welcome/google_sign_in_button.dart';
import 'widgets/welcome/email_sign_in_button.dart';
import 'widgets/welcome/terms_text.dart';

/// Full-screen welcome / onboarding view.
///
/// Replaces the old SplashView as the entry point (`/`).
/// Layout: vertically split — top half is branding (logo + title),
/// bottom half is image grid + action buttons + terms.
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  // Fade-in animation
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Auto-redirect if already signed in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/chat');
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Auth Handlers ──────────────────────────────────────────────────

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

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null && FirebaseAuth.instance.currentUser == null) {
        // User cancelled Google sign-in dialog
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) {
        _showError('Login Google gagal. Silakan coba lagi.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _firestoreService.saveUserProfile(user);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  void _handleEmailSignIn() {
    Navigator.pushNamed(context, '/login');
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background glow ──
          _buildBackgroundGlow(),
          // ── Main content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // ── Top: Branding ──
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LogoGlowWidget(),
                            SizedBox(height: 32),
                            TitleSection(),
                          ],
                        ),
                      ),
                      // ── Bottom: Grid + Buttons ──
                      Column(
                        children: [
                          const ImageGridDecoration(),
                          const SizedBox(height: 32),
                          // Buttons
                          _buildButtons(),
                          const TermsText(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Loading overlay ──
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      left: MediaQuery.of(context).size.width / 2 - 128,
      child: IgnorePointer(
        child: Container(
          width: 256,
          height: 256,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.20),
                blurRadius: 100,
                spreadRadius: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        GoogleSignInButton(onPressed: _handleGoogleSignIn),
        const SizedBox(height: 12),
        EmailSignInButton(onPressed: _handleEmailSignIn),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.backgroundDark.withValues(alpha: 0.60),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
