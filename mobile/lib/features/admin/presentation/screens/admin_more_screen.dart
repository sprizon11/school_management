import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/subscription_pricing.dart';
import '../admin_shell.dart';
import 'admin_profile_screen.dart';
import 'admin_add_class_screen.dart';
import 'admin_add_student_flow_screen.dart';
import 'admin_add_teacher_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_examinations_screen.dart';
import 'admin_fee_collection_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_subscription_screen.dart';
import 'admin_timetable_screen.dart';

class AdminMoreScreen extends ConsumerStatefulWidget {
  const AdminMoreScreen({super.key});

  @override
  ConsumerState<AdminMoreScreen> createState() => _AdminMoreScreenState();
}

class _AdminMoreScreenState extends ConsumerState<AdminMoreScreen> {
  bool _subscriptionActive = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final schoolId = ref.read(authProvider).user?.schoolId ?? '';
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _subscriptionActive = prefs.getBool('subscription_active_$schoolId') ?? false;
    });
  }

  void _open(Widget page) {
    openSmoothPage(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = ref.watch(authProvider.select((a) => a.user?.schoolName ?? 'Your School'));

    return ColoredBox(
      color: const Color(0xFFF4F6FB),
      child: Column(
        children: [
          const AdminHeader(title: 'More', subtitle: 'Settings & tools'),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadSubscriptionStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _section(
                    'Subscription',
                    [
                      _MenuItem(
                        icon: Icons.workspace_premium_rounded,
                        title: 'School app subscription',
                        subtitle: _subscriptionActive
                            ? 'Active plan · Tap to manage'
                            : '${SubscriptionPricing.formatInr(SubscriptionPricing.standardStudentRate)}/student · '
                                '${SubscriptionPricing.formatInr(SubscriptionPricing.teacherRate)}/teacher',
                        onTap: () => _open(const AdminSubscriptionScreen()),
                      ),
                    ],
                  ),
                  _section(
                    'Academic',
                    [
                      _MenuItem(
                        icon: Icons.fact_check_rounded,
                        title: 'Attendance',
                        onTap: () => _open(const AdminAttendanceScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.edit_note_rounded,
                        title: 'Examinations',
                        onTap: () => _open(const AdminExaminationsScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.calendar_month_rounded,
                        title: 'Timetable',
                        onTap: () => _open(const AdminTimetableScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.campaign_rounded,
                        title: 'Announcements',
                        onTap: () => _open(const AdminAnnouncementsScreen()),
                      ),
                    ],
                  ),
                  _section(
                    'Finance & reports',
                    [
                      _MenuItem(
                        icon: Icons.currency_rupee_rounded,
                        title: 'Fee collection',
                        onTap: () => _open(const AdminFeeCollectionScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.bar_chart_rounded,
                        title: 'Reports',
                        onTap: () => _open(const AdminReportsScreen()),
                      ),
                    ],
                  ),
                  _section(
                    'Add new',
                    [
                      _MenuItem(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Add student',
                        onTap: () => _open(const AdminAddStudentFlowScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.manage_accounts_rounded,
                        title: 'Add teacher',
                        onTap: () => _open(const AdminAddTeacherScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.menu_book_rounded,
                        title: 'Add class',
                        onTap: () => _open(const AdminAddClassScreen()),
                      ),
                    ],
                  ),
                  _section(
                    'Account',
                    [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        subtitle: 'School name, phone & address',
                        onTap: () => _open(const AdminProfileScreen()),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & support',
                        onTap: () => _showHelp(context),
                      ),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        titleColor: Colors.red,
                        iconColor: Colors.red,
                        onTap: () => adminLogout(ref, context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    schoolName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<_MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i].build(context),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 56, color: Color(0xFFE8EDF5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & support'),
        content: const Text(
          'For billing, onboarding, or technical help contact your platform provider.\n\n'
          'Email: support@schoolplatform.demo\n'
          'Phone: +91 98765 43210',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: titleColor ?? const Color(0xFF111827),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: titleColor ?? const Color(0xFFCBD5E1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
