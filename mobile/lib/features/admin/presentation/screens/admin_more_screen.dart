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

  void _open(Widget page) => openSmoothPage(context, page);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final fullName = user?.fullName ?? 'Admin';
    final schoolName = user?.schoolName ?? 'Your School';
    final topPad = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: const Color(0xFFF0F4FC),
      child: Column(
        children: [
          _PremiumHeader(
            fullName: fullName,
            schoolName: schoolName,
            topPad: topPad,
            onProfileTap: () => _open(const AdminProfileScreen()),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadSubscriptionStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                children: [
                  _PremiumSection(
                    title: 'Subscription',
                    accentColor: const Color(0xFFF5A623),
                    icon: Icons.star_rounded,
                    items: [
                      _PremiumItem(
                        icon: Icons.workspace_premium_rounded,
                        color: const Color(0xFFF5A623),
                        title: 'School app subscription',
                        subtitle: _subscriptionActive
                            ? 'Active plan · Tap to manage'
                            : '${SubscriptionPricing.formatInr(SubscriptionPricing.standardStudentRate)}/student · '
                                '${SubscriptionPricing.formatInr(SubscriptionPricing.teacherRate)}/teacher',
                        onTap: () => _open(const AdminSubscriptionScreen()),
                        badge: _subscriptionActive ? 'ACTIVE' : null,
                      ),
                    ],
                  ),
                  _PremiumSection(
                    title: 'Academic',
                    accentColor: AppColors.primary,
                    icon: Icons.school_rounded,
                    items: [
                      _PremiumItem(
                        icon: Icons.fact_check_rounded,
                        color: const Color(0xFF2F8DFF),
                        title: 'Attendance',
                        onTap: () => _open(const AdminAttendanceScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.edit_note_rounded,
                        color: const Color(0xFF6B5CE7),
                        title: 'Examinations',
                        onTap: () => _open(const AdminExaminationsScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF3B9EFF),
                        title: 'Timetable',
                        onTap: () => _open(const AdminTimetableScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.campaign_rounded,
                        color: const Color(0xFFFF5D6E),
                        title: 'Announcements',
                        onTap: () => _open(const AdminAnnouncementsScreen()),
                      ),
                    ],
                  ),
                  _PremiumSection(
                    title: 'Finance & Reports',
                    accentColor: const Color(0xFF16A34A),
                    icon: Icons.account_balance_wallet_rounded,
                    items: [
                      _PremiumItem(
                        icon: Icons.currency_rupee_rounded,
                        color: const Color(0xFF34B356),
                        title: 'Fee collection',
                        onTap: () => _open(const AdminFeeCollectionScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFF0D3DD4),
                        title: 'Reports',
                        onTap: () => _open(const AdminReportsScreen()),
                      ),
                    ],
                  ),
                  _PremiumSection(
                    title: 'Add New',
                    accentColor: const Color(0xFF5B6CFF),
                    icon: Icons.add_circle_rounded,
                    items: [
                      _PremiumItem(
                        icon: Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF5B6CFF),
                        title: 'Add student',
                        onTap: () => _open(const AdminAddStudentFlowScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.manage_accounts_rounded,
                        color: const Color(0xFF3DD16E),
                        title: 'Add teacher',
                        onTap: () => _open(const AdminAddTeacherScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFFF5A623),
                        title: 'Add class',
                        onTap: () => _open(const AdminAddClassScreen()),
                      ),
                    ],
                  ),
                  _PremiumSection(
                    title: 'Account',
                    accentColor: const Color(0xFF64748B),
                    icon: Icons.manage_accounts_rounded,
                    items: [
                      _PremiumItem(
                        icon: Icons.person_outline_rounded,
                        color: const Color(0xFF64748B),
                        title: 'Profile',
                        subtitle: 'School name, phone & address',
                        onTap: () => _open(const AdminProfileScreen()),
                      ),
                      _PremiumItem(
                        icon: Icons.help_outline_rounded,
                        color: const Color(0xFF3B9EFF),
                        title: 'Help & support',
                        onTap: () => _showHelp(context),
                      ),
                      _PremiumItem(
                        icon: Icons.logout_rounded,
                        color: Colors.red,
                        title: 'Logout',
                        titleColor: Colors.red,
                        onTap: () => adminLogout(ref, context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schoolName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

// ─────────────────────────────────────────────
// Premium header with profile card
// ─────────────────────────────────────────────
class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.fullName,
    required this.schoolName,
    required this.topPad,
    required this.onProfileTap,
  });

  final String fullName;
  final String schoolName;
  final double topPad;
  final VoidCallback onProfileTap;

  String get _initials => fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF051C6E), Color(0xFF0D3DD4), Color(0xFF2563EB), Color(0xFF4F8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -16,
            bottom: -10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + settings
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'More',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Settings & tools',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Settings icon button
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Profile card
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _initials.isEmpty ? 'A' : _initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schoolName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.70),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Premium section card
// ─────────────────────────────────────────────
class _PremiumSection extends StatelessWidget {
  const _PremiumSection({
    required this.title,
    required this.accentColor,
    required this.icon,
    required this.items,
  });

  final String title;
  final Color accentColor;
  final IconData icon;
  final List<_PremiumItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          // Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EAF6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B3FBF).withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    items[i].build(context),
                    if (i < items.length - 1)
                      Divider(
                        height: 1,
                        indent: 62,
                        endIndent: 16,
                        color: const Color(0xFFEEF3FC),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Premium menu item
// ─────────────────────────────────────────────
class _PremiumItem {
  const _PremiumItem({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final String? badge;

  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.07),
        highlightColor: color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Colored icon container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.70)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: titleColor ?? const Color(0xFF111827),
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: titleColor != null
                    ? titleColor!.withValues(alpha: 0.5)
                    : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
