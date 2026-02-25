import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';

/// A single chat session tile inside the grouped list.
///
/// Matches HTML: rounded-xl with leading icon container, truncated title, and
/// trailing contextual `more_vert` icon that appears on hover/press.
///
/// Active state: bg-surface-dark/50 with border, filled chat_bubble icon,
/// primary tint on icon container.
/// Inactive state: transparent bg, outlined icon, muted colors.
class ChatSessionTile extends StatelessWidget {
  const ChatSessionTile({
    super.key,
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: isDark
              ? AppColors.drawerSurface.withValues(alpha: 0.50)
              : AppColors.slate200,
          splashColor: isDark
              ? AppColors.drawerSurface
              : AppColors.slate300,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive
                  ? (isDark
                      ? AppColors.drawerSurface.withValues(alpha: 0.50)
                      : AppColors.slate200)
                  : Colors.transparent,
              border: isActive
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.transparent,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Leading icon container
                _buildIcon(isDark),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? (isDark ? AppColors.slate100 : AppColors.slate900)
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Context menu
                _ChatSessionContextMenu(
                  isDark: isDark,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isActive
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.20)
                : AppColors.primary.withValues(alpha: 0.10))
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.slate100),
      ),
      child: Icon(
        isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
        size: 20,
        color: isActive
            ? AppColors.primary
            : (isDark ? AppColors.slate400 : AppColors.slate500),
      ),
    );
  }
}

/// Trailing contextual menu with Rename / Delete actions.
class _ChatSessionContextMenu extends StatelessWidget {
  const _ChatSessionContextMenu({
    required this.isDark,
    required this.onRename,
    required this.onDelete,
  });

  final bool isDark;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: isDark ? AppColors.slate500 : AppColors.slate400,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      color: isDark ? AppColors.backgroundDark : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18,
                  color: isDark ? AppColors.slate300 : AppColors.slate700),
              const SizedBox(width: 10),
              Text('Ganti Nama',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppColors.slate100 : AppColors.slate900,
                  )),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text('Hapus',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.redAccent,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
