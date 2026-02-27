import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

// navigasi footer dengan tombol Pengaturan dan Tentang
class DrawerFooterNavigation extends StatelessWidget {
  const DrawerFooterNavigation({
    super.key,
    this.onSettings,
    this.onAbout,
  });

  final VoidCallback? onSettings;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _FooterButton(
          icon: Icons.settings_outlined,
          label: 'Pengaturan',
          isDark: isDark,
          onTap: onSettings ?? () {},
        ),
        const SizedBox(height: 4),
        _FooterButton(
          icon: Icons.info_outline,
          label: 'Tentang',
          isDark: isDark,
          onTap: onAbout ?? () {},
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: isDark
            ? AppColors.drawerSurface.withValues(alpha: 0.50)
            : AppColors.slate200,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
