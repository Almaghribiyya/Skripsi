import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';

/// Kartu referensi ayat Quran yang bisa di-expand di dalam pesan AI.
/// Menampilkan teks Arab dengan font Amiri + RTL yang benar,
/// diikuti transliterasi dan terjemahan Indonesia.
class AiReferenceCard extends StatefulWidget {
  const AiReferenceCard({super.key, required this.reference});

  final VerseReference reference;

  @override
  State<AiReferenceCard> createState() => _AiReferenceCardState();
}

class _AiReferenceCardState extends State<AiReferenceCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ref = widget.reference;

    // buat label tampilan, contoh: "Surah Al-Baqarah : 155"
    final String label = ref.surahName.isNotEmpty
        ? '${ref.surahName} : ${ref.ayatNumber}'
        : 'Ayat ${ref.ayatNumber}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
        ),
        color: isDark ? AppColors.surfaceDark : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ─── header ────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Icon(
                      Icons.expand_more,
                      color: AppColors.primary.withValues(alpha: 0.70),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ─── konten expandable ─────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.primary.withValues(alpha: 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 16, top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── teks Arab dengan font Amiri + RTL ──────
                      if (ref.arabicText.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              ref.arabicText,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.amiri(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                // height 2.2 mencegah harakat (diacritics) terpotong
                                height: 2.2,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // ── transliterasi latin ────────────────────
                      if (ref.transliteration.isNotEmpty) ...[
                        Text(
                          ref.transliteration,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: isDark
                                ? AppColors.sageLight
                                : AppColors.sageMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // ── terjemahan ─────────────────────────────
                      Text(
                        '"${ref.translation}"',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                          color: isDark
                              ? const Color(0xFF92C9B7)
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
