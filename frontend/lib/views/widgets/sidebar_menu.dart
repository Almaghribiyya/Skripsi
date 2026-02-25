import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../services/auth_service.dart';
import 'drawer/drawer_header_new_chat.dart';
import 'drawer/chat_session_grouped_list.dart';
import 'drawer/drawer_footer_navigation.dart';
import 'drawer/drawer_user_profile.dart';

/// Production-ready chat history navigation drawer.
///
/// Structure (top → bottom):
///   DrawerHeaderNewChat → ChatSessionGroupedList (scrollable, time-grouped)
///   → DrawerFooterNavigation → DrawerUserProfile
///
/// Integrates with [ChatViewModel] via Provider and exposes all required
/// callbacks: session selection, new chat, rename, delete, logout.
class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.slate200,
            ),
          ),
        ),
        child: SafeArea(
          child: Consumer<ChatViewModel>(
            builder: (context, viewModel, child) {
              return Column(
                children: [
                  // ── Header: New Chat button ──
                  DrawerHeaderNewChat(
                    onPressed: () {
                      viewModel.createNewSession();
                      Navigator.pop(context);
                    },
                  ),

                  // ── Scrollable grouped chat history ──
                  Expanded(
                    child: Scrollbar(
                      thickness: 6,
                      radius: const Radius.circular(3),
                      thumbVisibility: false,
                      child: ChatSessionGroupedList(
                        sessions: viewModel.sessions,
                        activeSessionId: viewModel.activeSessionId,
                        onSessionSelected: (sessionId) {
                          viewModel.switchSession(sessionId);
                          Navigator.pop(context);
                        },
                        onRenameSession: (sessionId) {
                          final session = viewModel.sessions
                              .firstWhere((s) => s.id == sessionId);
                          _showRenameDialog(
                            context,
                            viewModel,
                            sessionId,
                            session.title,
                          );
                        },
                        onDeleteSession: (sessionId) {
                          viewModel.deleteSession(sessionId);
                        },
                      ),
                    ),
                  ),

                  // ── Footer ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.slate200,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Settings & About
                        DrawerFooterNavigation(
                          onSettings: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
                          },
                          onAbout: () {
                            Navigator.pop(context);
                            _showAboutDialog(context);
                          },
                        ),
                        // Profil pengguna — navigasi ke pengaturan saat ditekan
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
                          },
                          child: DrawerUserProfile(
                            displayName: user?.displayName,
                            avatarUrl: user?.photoURL,
                            isOnline: true,
                            onLogout: () async {
                              final navigator = Navigator.of(context);
                              viewModel.clearAllSessions();
                              await AuthService().signOut();
                              navigator.pushNamedAndRemoveUntil(
                                  '/', (route) => false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Dialog tentang aplikasi Qur'an RAG.
  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.drawerSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.20),
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  "Qur'an RAG",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistem Tanya Jawab Al-Qur\'an berbasis AI '
                  '(Retrieval-Augmented Generation).',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.slate300 : AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 16),
                _aboutSectionTitle('Sumber Dataset', isDark),
                const SizedBox(height: 6),
                Text(
                  'Dataset resmi dari Kementerian Agama RI melalui '
                  'Lajnah Pentashihan Mushaf Al-Qur\'an (LPMQ).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 16),
                _aboutSectionTitle('Metadata Yang Tersedia', isDark),
                const SizedBox(height: 8),
                _aboutMetadataChip('Teks Arab (Rasm Usmani)', Icons.auto_stories, isDark),
                _aboutMetadataChip('Terjemahan Bahasa Indonesia', Icons.translate, isDark),
                _aboutMetadataChip('Transliterasi Latin', Icons.text_fields, isDark),
                _aboutMetadataChip('Tafsir Wajiz & Tahlili', Icons.menu_book, isDark),
                _aboutMetadataChip('Catatan Kaki', Icons.sticky_note_2_outlined, isDark),
                _aboutMetadataChip('Info Surah, Ayat, Juz, Halaman', Icons.info_outline, isDark),
                _aboutMetadataChip('Kategori Surah (Makkiyyah/Madaniyyah)', Icons.place_outlined, isDark),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '6.236 ayat',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Versi 1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Tutup',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _aboutSectionTitle(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : AppColors.slate900,
      ),
    );
  }

  Widget _aboutMetadataChip(String label, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.slate300 : AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog ganti nama obrolan.
  void _showRenameDialog(
    BuildContext context,
    ChatViewModel viewModel,
    String sessionId,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.drawerSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Ganti Nama',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : AppColors.slate900,
            ),
            decoration: InputDecoration(
              hintText: 'Masukkan judul baru',
              hintStyle: GoogleFonts.inter(
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.slate100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  viewModel.renameSession(sessionId, newTitle);
                }
                Navigator.pop(ctx);
              },
              child: Text(
                'Simpan',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}