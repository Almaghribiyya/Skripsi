import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';
import 'ai_reference_card.dart';
import 'message_action_chips.dart';

/// AI message bubble — left-aligned with avatar, header, colored surface,
/// optional reference cards, and action chips.
///
/// Matches HTML: AI avatar (primary/20 circle + icon) • "Quran AI" label •
/// timestamp • rounded-2xl rounded-tl-sm bg-[#23483c] bubble • references •
/// action chips.
class AiMessageBubble extends StatelessWidget {
  const AiMessageBubble({
    super.key,
    required this.message,
  });

  final MessageModel message;

  String get _timeLabel {
    final h = message.timestamp.hour.toString().padLeft(2, '0');
    final m = message.timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          _buildAvatar(),
          const SizedBox(width: 12),
          // Content column
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: "Quran AI" + timestamp
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        'Qur\'an RAG',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppColors.gray400 : AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Message bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.bubbleAi
                        : AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                ),
                // Reference cards
                if (message.verseReferences != null &&
                    message.verseReferences!.isNotEmpty)
                  ...message.verseReferences!.map(
                    (ref) => AiReferenceCard(reference: ref),
                  ),
                // Action chips
                MessageActionChips(
                  messageText: message.text,
                  messageId: message.id,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16), // right margin
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.20),
      ),
      child: const Icon(
        Icons.auto_awesome,
        size: 20,
        color: AppColors.primary,
      ),
    );
  }
}
