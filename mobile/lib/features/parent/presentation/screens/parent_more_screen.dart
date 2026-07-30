import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import 'parent_calendar_screen.dart';
import 'parent_homework_screen.dart';
import 'parent_leave_screen.dart';
import 'parent_library_screen.dart';
import 'parent_notifications_screen.dart';
import 'parent_report_card_screen.dart';

/// Secondary hub for the parent app — the home for features that don't warrant
/// their own nav tab. Grows as more features land.
class ParentMoreScreen extends ConsumerWidget {
  const ParentMoreScreen({super.key});

  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _headerInk = Color(0xFF1E1B4B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;

    final items = <({IconData icon, Color color, String label, String sub, Widget? page})>[
      (
        icon: Icons.workspace_premium_rounded,
        color: _accent,
        label: 'Report Card',
        sub: 'Exam results & rank',
        page: const ParentReportCardScreen(),
      ),
      (
        icon: Icons.event_rounded,
        color: const Color(0xFF7C3AED),
        label: 'School Calendar',
        sub: 'Holidays, exams & events',
        page: const ParentCalendarScreen(),
      ),
      (
        icon: Icons.menu_book_rounded,
        color: AppColors.statOrange,
        label: 'Homework',
        sub: "Your child's assignments",
        page: const ParentHomeworkScreen(),
      ),
      (
        icon: Icons.event_note_rounded,
        color: const Color(0xFF3B82F6),
        label: 'Leave Application',
        sub: 'Request & track leave',
        page: const ParentLeaveScreen(),
      ),
      (
        icon: Icons.local_library_rounded,
        color: const Color(0xFF0EA5E9),
        label: 'Library',
        sub: 'Borrowed books & due dates',
        page: const ParentLibraryScreen(),
      ),
      (
        icon: Icons.notifications_rounded,
        color: AppColors.statGreen,
        label: 'Notifications',
        sub: 'Messages & school updates',
        page: const ParentNotificationsScreen(),
      ),
    ];

    return Container(
      color: const Color(0xFFF8F9FE),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, top + 14, 16, 110),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              'More',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _headerInk,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 16),
            child: Text(
              'Everything for your child',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0x8A1E1B4B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            EntranceFadeItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _tile(context, items[i]),
              ),
            ),
          const SizedBox(height: 8),
          EntranceFadeItem(
            index: items.length,
            child: _logoutTile(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    ({IconData icon, Color color, String label, String sub, Widget? page}) item,
  ) {
    return PressableScale(
      onTap: item.page == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => item.page!),
              ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, size: 22, color: item.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.sub,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: _ink.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutTile(BuildContext context, WidgetRef ref) {
    const red = Color(0xFFEF4444);
    return PressableScale(
      onTap: () => ref.read(authProvider.notifier).logout(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.logout_rounded, size: 22, color: red),
            ),
            const SizedBox(width: 14),
            const Text(
              'Log out',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFEFEFF6)),
    boxShadow: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}
