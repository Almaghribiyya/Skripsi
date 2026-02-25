import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';

/// Sticky top app bar matching the HTML header.
///
/// Menu button (left) • "Quran AI" title (center) • Profile avatar (right).
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    this.onMenuPressed,
    this.onProfilePressed,
    this.profileImageUrl,
  });

  final VoidCallback? onMenuPressed;
  final VoidCallback? onProfilePressed;
  final String? profileImageUrl;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.gray800 : AppColors.gray200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Menu button
                IconButton(
                  onPressed: onMenuPressed,
                  icon: Icon(
                    Icons.menu,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                  splashRadius: 20,
                  tooltip: 'Menu',
                ),
                // Title
                Expanded(
                  child: Text(
                    'Qur\'an RAG',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                ),
                // Profile avatar
                GestureDetector(
                  onTap: onProfilePressed,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: profileImageUrl != null &&
                              profileImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profileImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: AppColors.gray700,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.gray700,
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.gray400,
                                  size: 18,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.gray700,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.gray400,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
