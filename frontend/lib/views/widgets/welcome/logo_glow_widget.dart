import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

// Widget logo dengan efek cahaya gradient animasi
class LogoGlowWidget extends StatefulWidget {
  const LogoGlowWidget({super.key});

  @override
  State<LogoGlowWidget> createState() => _LogoGlowWidgetState();
}

class _LogoGlowWidgetState extends State<LogoGlowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.20, end: 0.40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // lingkaran cahaya luar
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: _glowAnimation.value),
                    AppColors.primaryDark.withValues(alpha: _glowAnimation.value),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.5),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            // kontainer ikon dengan sudut membulat
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book,
                color: AppColors.primary,
                size: 56,
              ),
            ),
          ],
        );
      },
    );
  }
}
