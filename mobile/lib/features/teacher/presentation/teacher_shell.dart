import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'providers/teacher_shell_provider.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'screens/teacher_chat_screen.dart';
import 'screens/teacher_students_screen.dart';
import 'screens/teacher_reports_screen.dart';
import 'screens/teacher_more_screen.dart';

const _dashBg = Color(0xFFF8F9FE);

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
      backgroundColor: _dashBg,
      body: IndexedStack(
        index: index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Dashboard'),
                _navItem(1, Icons.chat_rounded, Icons.chat_outlined, 'Chat'),
                _navItem(2, Icons.people_rounded, Icons.people_outline_rounded, 'Students'),
                _navItem(3, Icons.insert_chart_rounded, Icons.insert_chart_outlined_rounded, 'Reports'),
                _navItem(4, Icons.more_horiz_rounded, Icons.more_horiz, 'More'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData selectedIcon, IconData icon, String label) {
    final selected = ref.watch(teacherShellTabProvider) == i;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(teacherShellTabProvider.notifier).state = i,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 23,
              color: selected ? AppColors.teacherPrimary : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.teacherPrimary : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: selected ? 32 : 0,
              decoration: BoxDecoration(
                color: AppColors.teacherPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
