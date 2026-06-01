import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'screens/parent_home_screen.dart';
import 'screens/parent_attendance_screen.dart';
import 'screens/parent_results_screen.dart';
import 'screens/parent_fees_screen.dart';
import 'screens/parent_profile_screen.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;

  final _screens = const [
    ParentHomeScreen(),
    ParentAttendanceScreen(),
    ParentResultsScreen(),
    ParentFeesScreen(),
    ParentProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.parentPrimary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.grade_outlined), label: 'Results'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Fees'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
