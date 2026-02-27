import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_theme.dart';

// baris aksi di bawah pesan AI: salin dan bagikan
class MessageActionChips extends StatefulWidget {
  const MessageActionChips({
    super.key,
    required this.messageText,
    required this.messageId,
  });

  final String messageText;
  final String messageId;

  @override
  State<MessageActionChips> createState() => _MessageActionChipsState();
}

class _MessageActionChipsState extends State<MessageActionChips> {
  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.messageText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks berhasil disalin'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleShare() {
    final shareText =
        "[Qur'an RAG]\n\n${widget.messageText}";
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionChip(
            icon: Icons.content_copy,
            label: 'Salin',
            isDark: isDark,
            onTap: _handleCopy,
          ),
          _ActionChip(
            icon: Icons.share,
            label: 'Bagikan',
            isDark: isDark,
            onTap: _handleShare,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
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
    final borderColor = isDark ? AppColors.gray700 : AppColors.gray200;
    final textColor = isDark ? const Color(0xFFCBD5E1) : AppColors.gray600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
