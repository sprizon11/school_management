import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'screens/teacher_students_screen.dart';
import 'screens/teacher_reports_screen.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _index = 0;

  static const _screens = [
    TeacherDashboardScreen(),
    Center(child: Text('Classes')),
    TeacherStudentsScreen(),
    TeacherReportsScreen(),
    Center(child: Text('More')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.teacherPrimary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.class_outlined), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
