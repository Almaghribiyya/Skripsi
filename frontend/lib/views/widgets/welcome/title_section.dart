import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

/// Title section with "Welcome to" heading + gradient "Quran AI" + subtitle.
///
/// Matches the HTML `<h1>` + `<p>` block with identical hierarchy.
class TitleSection extends StatelessWidget {
  const TitleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Heading
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Selamat Datang di\n',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.2,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                WidgetSpan(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ).createShader(bounds),
                    child: Text(
                      'Qur\'an RAG',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.2,
                        color: Colors.white, // masked by shader
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Subtitle
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'Teman bertanya Al-Qur\'an',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
