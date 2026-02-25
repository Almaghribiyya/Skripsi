import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';

/// Expandable accordion for Quranic verse references inside AI messages.
///
/// Replicates the HTML `<details>` element with expand/collapse animation,
/// verse text, and "Read Context" action.
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

    // Build display label: "Surah Al-Baqarah 2:155" style
    final String label =
        ref.surahName.isNotEmpty ? '${ref.surahName} ${ref.ayatNumber}' : 'Ayat ${ref.ayatNumber}';

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
          // Summary / header
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book,
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
          // Expandable body
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
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Arabic text (RTL)
                      if (ref.arabicText.isNotEmpty) ...[
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            ref.arabicText,
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.8,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Translation
                      Text(
                        '"${ref.translation}"',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
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
