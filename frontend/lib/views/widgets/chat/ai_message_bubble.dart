import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';
import 'ai_reference_card.dart';
import 'message_action_chips.dart';

// bubble pesan AI, rata kiri dengan avatar dan referensi ayat
class AiMessageBubble extends StatelessWidget {
  const AiMessageBubble({
    super.key,
    required this.message,
    this.isLastAiMessage = false,
    this.onRegenerate,
    this.onDelete,
  });

  final MessageModel message;

  // apakah ini pesan AI terakhir di percakapan
  final bool isLastAiMessage;

  // callback regenerate (hanya muncul di pesan AI terakhir)
  final VoidCallback? onRegenerate;

  // callback hapus pesan
  final VoidCallback? onDelete;

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
          // avatar AI
          _buildAvatar(),
          const SizedBox(width: 12),
          // kolom konten
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header: nama AI + waktu
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
                // bubble pesan
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
                  child: MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.7,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      strong: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.7,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      em: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      h1: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      h2: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      h3: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      listBullet: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.5,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                      code: GoogleFonts.sourceCodePro(
                        fontSize: 14,
                        color: AppColors.primary,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.primary.withValues(alpha: 0.08),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.40),
                            width: 3,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                // kartu referensi
                if (message.verseReferences != null &&
                    message.verseReferences!.isNotEmpty)
                  ...message.verseReferences!.map(
                    (ref) => AiReferenceCard(reference: ref),
                  ),
                // tombol aksi
                MessageActionChips(
                  messageText: message.text,
                  messageId: message.id,
                  onRegenerate: isLastAiMessage ? onRegenerate : null,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16), // margin kanan
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
