import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../viewmodels/chat_viewmodel.dart';

// halaman pengaturan aplikasi
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          // header
          _SettingsHeader(isDark: isDark),

          // konten utama
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                children: [
                  // profil
                  _ProfileSection(user: user, isDark: isDark),

                  // daftar pengaturan
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _SettingsGroup(
                      isDark: isDark,
                      children: [
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          iconBgColor: isDark
                              ? const Color(0xFF0D3D2E)
                              : const Color(0xFFF0FDFA),
                          iconColor: isDark
                              ? const Color(0xFF2DD4BF)
                              : const Color(0xFF0D9488),
                          title: 'Tema Aplikasi',
                          subtitle: isDark ? 'Gelap' : 'Terang',
                          isDark: isDark,
                          onTap: () => _showThemeSheet(context, isDark),
                        ),
                      ],
                    ),
                  ),

                  // tombol keluar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _LogoutButton(
                      isDark: isDark,
                      onTap: () => _handleLogout(context),
                    ),
                  ),

                  // label versi
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    child: Text(
                      "Qur'an RAG v1.0.0",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.slate700 : AppColors.slate400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // aksi

  void _showThemeSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // garis handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700 : AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tema Aplikasi',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fitur tema akan dikembangkan lebih lanjut.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 16),
                _ThemeOption(
                  icon: Icons.dark_mode,
                  label: 'Gelap',
                  isSelected: isDark,
                  isDark: isDark,
                ),
                _ThemeOption(
                  icon: Icons.light_mode,
                  label: 'Terang',
                  isSelected: !isDark,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    context.read<ChatViewModel>().clearAllSessions();
    await AuthService().signOut();
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }
}

// widget header pengaturan
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withValues(alpha: 0.80)
            : AppColors.backgroundLight.withValues(alpha: 0.80),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.slate700.withValues(alpha: 0.50)
                : AppColors.slate200,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // tombol tutup
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  size: 24,
                  color: isDark ? AppColors.slate300 : AppColors.slate500,
                ),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              // judul tengah
              Expanded(
                child: Text(
                  'Pengaturan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
              // penyeimbang biar judul tetap di tengah
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// bagian profil pengguna
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.user, required this.isDark});

  final User? user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Pengguna';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // avatar
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.surfaceDark : AppColors.slate200,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fallbackAvatar(displayName),
                    )
                  : _fallbackAvatar(displayName),
            ),
          ),
          const SizedBox(height: 16),
          // nama
          Text(
            displayName,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          const SizedBox(height: 4),
          // email
          Text(
            email,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String name) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      color: AppColors.primary.withValues(alpha: 0.20),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// grup pengaturan dalam kartu
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.isDark,
    required this.children,
  });

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.slate700.withValues(alpha: 0.50)
              : AppColors.slate200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _interleave(children),
      ),
    );
  }

  List<Widget> _interleave(List<Widget> items) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? AppColors.slate700.withValues(alpha: 0.50)
                  : AppColors.slate100,
            ),
          ),
        );
      }
    }
    return result;
  }
}

// satu baris item pengaturan
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.isDark,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.slate100 : AppColors.slate900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// tombol logout
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.10)
              : const Color(0xFFFEF2F2),
        ),
        child: Center(
          child: Text(
            'Keluar',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
            ),
          ),
        ),
      ),
    );
  }
}

// opsi tema di bottom sheet
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.slate400 : AppColors.slate500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
