import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Navigasi setelah 3 detik: ke /chat jika sudah login, ke /login jika belum
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          Navigator.pushReplacementNamed(context, '/chat');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF064C3E);
    const backgroundDark = Color(0xFF10221E);

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        children: [
          // Central Icon Container
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow Effect
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Icon Background Circle
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: backgroundDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: primaryColor,
                        size: 64,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  "Al-Qur'an AI",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Footer
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              "Powered by AI",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}