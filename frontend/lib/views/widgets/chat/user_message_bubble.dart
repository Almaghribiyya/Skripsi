import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';

/// User message bubble — right-aligned with transparent bg + border.
///
/// Supports copy on all prompts and edit on the last user prompt
/// (similar to Gemini/ChatGPT mobile).
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    super.key,
    required this.text,
    required this.timestamp,
    this.avatarUrl,
    this.isLastUserMessage = false,
    this.onEdit,
  });

  final String text;
  final DateTime timestamp;
  final String? avatarUrl;

  /// Whether this is the last user message in the conversation.
  final bool isLastUserMessage;

  /// Called when user taps the edit button (only shown on last user message).
  final VoidCallback? onEdit;

  String get _timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _handleCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt berhasil disalin'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48), // left spacing for max-width
          // Bubble + timestamp column
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isDark ? AppColors.gray600 : AppColors.gray200,
                    ),
                  ),
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Action row: timestamp + copy + edit (last only)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color:
                              isDark ? AppColors.gray400 : AppColors.gray500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Copy button — always shown
                      _SmallActionButton(
                        icon: Icons.content_copy,
                        tooltip: 'Salin',
                        isDark: isDark,
                        onTap: () => _handleCopy(context),
                      ),
                      // Edit button — only on last user message
                      if (isLastUserMessage && onEdit != null) ...[
                        const SizedBox(width: 4),
                        _SmallActionButton(
                          icon: Icons.edit,
                          tooltip: 'Edit',
                          isDark: isDark,
                          onTap: onEdit!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          _buildAvatar(isDark),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.gray700 : AppColors.gray200,
        border: Border.all(
          color: isDark ? AppColors.gray600 : AppColors.gray200,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: 16,
                  color: isDark ? AppColors.gray400 : AppColors.gray500,
                ),
              )
            : Icon(
                Icons.person,
                size: 16,
                color: isDark ? AppColors.gray400 : AppColors.gray500,
              ),
      ),
    );
  }
}

/// Small icon-only action button used below user message bubbles.
class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.gray400 : AppColors.gray500;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
