import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

// tombol aksi utama "Obrolan Baru" di bagian atas drawer,
// dengan efek scale saat ditekan
class DrawerHeaderNewChat extends StatefulWidget {
  const DrawerHeaderNewChat({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<DrawerHeaderNewChat> createState() => _DrawerHeaderNewChatState();
}

class _DrawerHeaderNewChatState extends State<DrawerHeaderNewChat> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.98);
  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onPressed();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: AppColors.backgroundDark, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Obrolan Baru',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.backgroundDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
