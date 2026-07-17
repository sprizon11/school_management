import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../admin_shell.dart';
import '../screens/admin_attendance_screen.dart';
import '../screens/admin_fee_collection_screen.dart';
import '../screens/admin_reports_screen.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key, this.onTabSelect});

  final ValueChanged<int>? onTabSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((a) => a.user));
    final fullName = user?.fullName ?? 'Admin';
    final email = user?.email ?? 'admin@school.demo';

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            _profileHeader(context, fullName, email),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  _sectionLabel('Main'),
                  _item(
                    context,
                    icon: Icons.home_rounded,
                    label: 'Dashboard',
                    color: AppColors.primary,
                    onTap: () => _goTab(context, 0),
                  ),
                  _item(
                    context,
                    icon: Icons.groups_rounded,
                    label: 'Students',
                    color: const Color(0xFF4F6FFF),
                    onTap: () => _goTab(context, 1),
                  ),
                  _item(
                    context,
                    icon: Icons.school_rounded,
                    label: 'Teachers',
                    color: const Color(0xFF3CCB6F),
                    onTap: () => _goTab(context, 2),
                  ),
                  _item(
                    context,
                    icon: Icons.menu_book_rounded,
                    label: 'Classes',
                    color: const Color(0xFFF5A623),
                    onTap: () => _goTab(context, 3),
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Management'),
                  _item(
                    context,
                    icon: Icons.fact_check_rounded,
                    label: 'Attendance',
                    color: const Color(0xFF2F8DFF),
                    onTap: () =>
                        _openPage(context, const AdminAttendanceScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.payments_rounded,
                    label: 'Fee Collection',
                    color: const Color(0xFF34B356),
                    onTap: () =>
                        _openPage(context, const AdminFeeCollectionScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                    color: const Color(0xFFFF5D6E),
                    onTap: () => _openPage(context, const AdminReportsScreen()),
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Account'),
                  _item(
                    context,
                    icon: Icons.grid_view_rounded,
                    label: 'More',
                    color: const Color(0xFF6B7280),
                    onTap: () => _goTab(context, 4),
                  ),
                  _item(
                    context,
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      adminLogout(ref, context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goTab(BuildContext context, int index) {
    Navigator.pop(context);
    onTabSelect?.call(index);
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.pop(context);
    openSmoothPage(context, page);
  }

  Widget _profileHeader(BuildContext context, String fullName, String email) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0835B8), Color(0xFF1B5FFF), Color(0xFF3D7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
