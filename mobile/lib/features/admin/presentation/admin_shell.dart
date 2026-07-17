import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_students_screen.dart';
import 'screens/admin_teachers_screen.dart';
import 'screens/admin_classes_screen.dart';
import 'screens/admin_more_screen.dart';
import 'widgets/admin_sidebar.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final List<Widget> _screens;

  // Runs a short fade+rise whenever the tab changes. The IndexedStack itself
  // is never rebuilt with a new key, so each tab keeps its state — the
  // animation plays over the top of the swap.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _tabCurve = CurvedAnimation(
    parent: _tabFade,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _screens = [
      AdminDashboardScreen(onTabSelect: _selectTab),
      const AdminStudentsScreen(),
      const AdminTeachersScreen(),
      const AdminClassesScreen(),
      const AdminMoreScreen(),
    ];
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (MediaQuery.of(context).disableAnimations) {
      _tabFade.value = 1;
    } else {
      _tabFade.forward(from: 0.25);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // The drawer lives here rather than on the dashboard, so every tab can
      // open it via Scaffold.of(context) — they all sit under this Scaffold.
      drawer: AdminSidebar(onTabSelect: _selectTab),
      drawerEnableOpenDragGesture: false,
      body: FadeTransition(
        opacity: _tabCurve,
        child: AnimatedBuilder(
          animation: _tabCurve,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 10 * (1 - _tabCurve.value)),
            child: child,
          ),
          child: IndexedStack(index: _index, children: _screens),
        ),
      ),
      bottomNavigationBar: _LiquidNavBar(index: _index, onTap: _selectTab),
    );
  }
}

class _LiquidNavBar extends StatelessWidget {
  const _LiquidNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Dashboard'),
    (icon: Icons.groups_rounded, label: 'Students'),
    (icon: Icons.school_rounded, label: 'Teachers'),
    (icon: Icons.menu_book_rounded, label: 'Classes'),
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
                  color: const Color(0xFF1B3FBF).withValues(alpha: 0.16),
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
                    _navItem(i, _items[i].icon, _items[i].label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
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
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
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

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerBlueStart, AppColors.headerBlueEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child:
          child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
            ],
          ),
    );
  }
}

void adminLogout(WidgetRef ref, BuildContext context) {
  ref.read(authProvider.notifier).logout();
}
