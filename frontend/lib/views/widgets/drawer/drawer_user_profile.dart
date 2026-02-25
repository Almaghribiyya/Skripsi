import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';

/// User profile snippet at the bottom of the drawer.
///
/// Displays: gradient-bordered avatar with online status indicator,
/// username, role label, and logout button.
class DrawerUserProfile extends StatelessWidget {
  const DrawerUserProfile({
    super.key,
    this.displayName,
    this.avatarUrl,
    this.isOnline = true,
    required this.onLogout,
  });

  final String? displayName;
  final String? avatarUrl;
  final bool isOnline;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = displayName ?? 'Pengguna';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.slate200,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar with gradient border + online indicator
            _GradientAvatar(
              imageUrl: avatarUrl,
              isOnline: isOnline,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
            ),
            // Logout button
            IconButton(
              onPressed: onLogout,
              icon: Icon(
                Icons.logout,
                size: 20,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
              tooltip: 'Keluar',
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar wrapped in a gradient border ring with online status dot.
class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar({
    this.imageUrl,
    this.isOnline = true,
    required this.isDark,
  });

  final String? imageUrl;
  final bool isOnline;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          // Gradient border
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.gray700,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.gray700,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.slate400,
                            size: 16,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.gray700,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.slate400,
                          size: 16,
                        ),
                      ),
              ),
            ),
          ),
          // Online status indicator
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
