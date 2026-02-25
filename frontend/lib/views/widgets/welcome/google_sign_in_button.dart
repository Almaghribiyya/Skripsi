import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

/// Primary CTA — "Continue with Google" green button with Google logo SVG
/// equivalent (painted via CustomPaint) and press-scale animation.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.02,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.forward();
  void _onTapUp(TapUpDetails _) {
    _scaleCtrl.reverse();
    widget.onPressed();
  }

  void _onTapCancel() => _scaleCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google "G" icon painted inline
              const _GoogleIcon(size: 20),
              const SizedBox(width: 12),
              Text(
                'Lanjutkan dengan Google',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.backgroundDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified Google "G" icon using built-in Material icon to avoid
/// external SVG dependency. Styled to match the white-on-primary design.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Scaled coordinates based on 24x24 viewbox → current size
    final double scale = s / 24.0;

    // Blue (top-right arc) — rendered as white with slight transparency
    paint.color = Colors.white.withValues(alpha: 0.9);
    final Path bluePath = Path()
      ..moveTo(23.766 * scale, 12.276 * scale)
      ..cubicTo(23.766 * scale, 11.461 * scale, 23.700 * scale, 10.641 * scale,
          23.559 * scale, 9.838 * scale)
      ..lineTo(12.24 * scale, 9.838 * scale)
      ..lineTo(12.24 * scale, 14.459 * scale)
      ..lineTo(18.722 * scale, 14.459 * scale)
      ..cubicTo(18.453 * scale, 15.949 * scale, 17.589 * scale, 17.268 * scale,
          16.323 * scale, 18.106 * scale)
      ..lineTo(16.323 * scale, 21.104 * scale)
      ..lineTo(20.190 * scale, 21.104 * scale)
      ..cubicTo(22.461 * scale, 19.014 * scale, 23.766 * scale, 15.927 * scale,
          23.766 * scale, 12.276 * scale)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Green (bottom-right)
    paint.color = Colors.white.withValues(alpha: 0.7);
    final Path greenPath = Path()
      ..moveTo(12.24 * scale, 24.001 * scale)
      ..cubicTo(15.477 * scale, 24.001 * scale, 18.206 * scale, 22.938 * scale,
          20.190 * scale, 21.104 * scale)
      ..lineTo(16.323 * scale, 18.106 * scale)
      ..cubicTo(15.252 * scale, 18.838 * scale, 13.863 * scale, 19.252 * scale,
          12.245 * scale, 19.252 * scale)
      ..cubicTo(9.114 * scale, 19.252 * scale, 6.459 * scale, 17.140 * scale,
          5.507 * scale, 14.300 * scale)
      ..lineTo(1.517 * scale, 14.300 * scale)
      ..lineTo(1.517 * scale, 17.391 * scale)
      ..cubicTo(3.554 * scale, 21.443 * scale, 7.703 * scale, 24.001 * scale,
          12.24 * scale, 24.001 * scale)
      ..close();
    canvas.drawPath(greenPath, paint);

    // Yellow (bottom-left)
    paint.color = Colors.white.withValues(alpha: 0.6);
    final Path yellowPath = Path()
      ..moveTo(5.503 * scale, 14.300 * scale)
      ..cubicTo(5.002 * scale, 12.810 * scale, 5.002 * scale, 11.196 * scale,
          5.503 * scale, 9.706 * scale)
      ..lineTo(5.503 * scale, 6.615 * scale)
      ..lineTo(1.517 * scale, 6.615 * scale)
      ..cubicTo(-0.186 * scale, 10.006 * scale, -0.186 * scale, 14.000 * scale,
          1.517 * scale, 17.391 * scale)
      ..lineTo(5.503 * scale, 14.300 * scale)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Red (top-left)
    paint.color = Colors.white.withValues(alpha: 0.8);
    final Path redPath = Path()
      ..moveTo(12.24 * scale, 4.750 * scale)
      ..cubicTo(13.951 * scale, 4.723 * scale, 15.604 * scale, 5.367 * scale,
          16.843 * scale, 6.549 * scale)
      ..lineTo(20.270 * scale, 3.123 * scale)
      ..cubicTo(18.100 * scale, 1.086 * scale, 15.221 * scale, -0.034 * scale,
          12.24 * scale, 0.001 * scale)
      ..cubicTo(7.703 * scale, 0.001 * scale, 3.554 * scale, 2.558 * scale,
          1.517 * scale, 6.615 * scale)
      ..lineTo(5.503 * scale, 9.706 * scale)
      ..cubicTo(6.451 * scale, 6.862 * scale, 9.109 * scale, 4.750 * scale,
          12.24 * scale, 4.750 * scale)
      ..close();
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
