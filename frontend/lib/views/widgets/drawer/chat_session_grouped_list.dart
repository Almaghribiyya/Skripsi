import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/app_theme.dart';
import '../../../models/message_model.dart';
import 'chat_session_tile.dart';

// kategori pengelompokan sesi chat berdasarkan waktu
enum _SessionGroup {
  today('Hari Ini'),
  previous7Days('7 Hari Terakhir'),
  previous30Days('30 Hari Terakhir'),
  older('Lebih Lama');

  const _SessionGroup(this.label);
  final String label;
}

// mengelompokkan sesi berdasarkan waktu relatif terhadap sekarang
// dan menampilkannya sebagai seksi berlabel dengan ChatSessionTile
class ChatSessionGroupedList extends StatelessWidget {
  const ChatSessionGroupedList({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSessionSelected,
    required this.onRenameSession,
    required this.onDeleteSession,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final void Function(String sessionId) onSessionSelected;
  final void Function(String sessionId) onRenameSession;
  final void Function(String sessionId) onDeleteSession;

  // hitung bucket pengelompokan dari timestamp sesi
  Map<_SessionGroup, List<ChatSession>> _groupSessions() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
    final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

    final groups = <_SessionGroup, List<ChatSession>>{};

    for (final session in sessions) {
      final date = session.createdAt;
      final _SessionGroup group;

      if (!date.isBefore(todayStart)) {
        group = _SessionGroup.today;
      } else if (!date.isBefore(sevenDaysAgo)) {
        group = _SessionGroup.previous7Days;
      } else if (!date.isBefore(thirtyDaysAgo)) {
        group = _SessionGroup.previous30Days;
      } else {
        group = _SessionGroup.older;
      }

      (groups[group] ??= []).add(session);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _groupSessions();

    // iterasi berurut sesuai enum biar urutan seksi tetap konsisten
    final orderedGroups = _SessionGroup.values
        .where((g) => groups.containsKey(g))
        .toList();

    if (orderedGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Belum ada percakapan.\nKetuk "Obrolan Baru" untuk memulai.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    // ratakan jadi satu list scrollable dengan header seksi
    final List<Widget> children = [];
    for (final group in orderedGroups) {
      final sessionsInGroup = groups[group]!;
      children.add(_SectionLabel(label: group.label, isDark: isDark));
      for (final session in sessionsInGroup) {
        children.add(
          ChatSessionTile(
            title: session.title,
            isActive: session.id == activeSessionId,
            onTap: () => onSessionSelected(session.id),
            onRename: () => onRenameSession(session.id),
            onDelete: () => onDeleteSession(session.id),
          ),
        );
      }
      children.add(const SizedBox(height: 16));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: children,
    );
  }
}

// label header seksi (misal "HARI INI", "7 HARI TERAKHIR")
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.70)
              : AppColors.slate500,
        ),
      ),
    );
  }
}
