import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/teacher_shell_provider.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'screens/teacher_chat_screen.dart';
import 'screens/teacher_students_screen.dart';
import 'screens/teacher_reports_screen.dart';
import 'screens/teacher_more_screen.dart';
import 'widgets/teacher_sidebar.dart';
import 'widgets/teacher_ui.dart';

class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key});

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  static const _screens = [
    TeacherDashboardScreen(),
    TeacherChatScreen(),
    TeacherStudentsScreen(),
    TeacherReportsScreen(),
    TeacherMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(teacherShellTabProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: teacherBg,
      // Drawer lives on the shell so every tab can open it via
      // Scaffold.of(context) — same arrangement as the admin shell.
      drawer: TeacherSidebar(
        onTabSelect: (i) =>
            ref.read(teacherShellTabProvider.notifier).state = i,
      ),
      drawerEnableOpenDragGesture: false,
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: _TeacherLiquidNavBar(
        index: index,
        onTap: (i) => ref.read(teacherShellTabProvider.notifier).state = i,
      ),
    );
  }
}

class _TeacherLiquidNavBar extends StatelessWidget {
  const _TeacherLiquidNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Dashboard'),
    (icon: Icons.chat_bubble_rounded, label: 'Chat'),
    (icon: Icons.people_alt_rounded, label: 'Students'),
    (icon: Icons.insert_chart_rounded, label: 'Reports'),
    (icon: Icons.grid_view_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe > 0 ? bottomSafe : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: teacherHeaderStart.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _navItem(i, _items[i].icon),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon) {
    final selected = i == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 24,
          color: selected ? Colors.white : const Color(0xFF6B7686),
        ),
      ),
    );
  }
}
