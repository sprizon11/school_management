import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../admin_shell.dart';
import 'admin_profile_screen.dart';
import 'admin_teachers_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_fee_collection_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_subscription_screen.dart';

class AdminMoreScreen extends ConsumerStatefulWidget {
  const AdminMoreScreen({super.key});

  @override
  ConsumerState<AdminMoreScreen> createState() => _AdminMoreScreenState();
}

class _AdminMoreScreenState extends ConsumerState<AdminMoreScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF6D5DE8);

  void _open(Widget page) => openSmoothPage(context, page);

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final fullName = user?.fullName ?? 'Admin';
    final schoolName = user?.schoolName ?? 'Your School';
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return ColoredBox(
      color: const Color(0xFFF5F5FB),
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
          children: [
            _header(),
            const SizedBox(height: 18),
            _profileCard(fullName, schoolName),
            const SizedBox(height: 22),
            _sectionLabel('Management'),
            const SizedBox(height: 10),
            _menuCard([
              _MenuItem(
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF6366F1),
                title: 'School Profile',
                subtitle: 'View and edit school information',
                onTap: () => _open(const AdminProfileScreen()),
              ),
              _MenuItem(
                icon: Icons.groups_rounded,
                color: const Color(0xFF22C55E),
                title: 'Teachers',
                subtitle: 'Manage all teachers',
                onTap: () => _open(const AdminTeachersScreen()),
              ),
              _MenuItem(
                icon: Icons.school_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Classes & Sections',
                subtitle: 'Manage classes and sections',
                onTap: () => _open(const AdminClassesScreen()),
              ),
              _MenuItem(
                icon: Icons.currency_rupee_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Fee Structures',
                subtitle: 'Create and manage fee structures',
                onTap: () => _open(const AdminFeeCollectionScreen()),
              ),
              _MenuItem(
                icon: Icons.description_rounded,
                color: const Color(0xFF3B82F6),
                title: 'Reports',
                subtitle: 'View all school reports',
                onTap: () => _open(const AdminReportsScreen()),
              ),
            ]),
            const SizedBox(height: 22),
            _sectionLabel('Communication'),
            const SizedBox(height: 10),
            _menuCard([
              _MenuItem(
                icon: Icons.campaign_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Announcements',
                subtitle: 'View and manage announcements',
                onTap: () => _open(const AdminAnnouncementsScreen()),
              ),
              _MenuItem(
                icon: Icons.forum_rounded,
                color: const Color(0xFFEC4899),
                title: 'Messages',
                subtitle: 'View messages and conversations',
                onTap: () => _snack('Messages — coming soon'),
              ),
              _MenuItem(
                icon: Icons.mail_outline_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Email Notifications',
                subtitle: 'Manage email notification settings',
                onTap: () => _snack('Email settings — coming soon'),
              ),
            ]),
            const SizedBox(height: 22),
            _sectionLabel('Settings & Support'),
            const SizedBox(height: 10),
            _menuCard([
              _MenuItem(
                icon: Icons.shield_outlined,
                color: const Color(0xFF3B82F6),
                title: 'Account Settings',
                subtitle: 'Manage your account settings',
                onTap: () => _open(const AdminSubscriptionScreen()),
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                color: const Color(0xFF22C55E),
                title: 'Help & Support',
                subtitle: 'Get help and view FAQs',
                onTap: _showHelp,
              ),
              _MenuItem(
                icon: Icons.logout_rounded,
                color: const Color(0xFFEF4444),
                title: 'Logout',
                subtitle: 'Sign out from your account',
                danger: true,
                onTap: () => adminLogout(ref, context),
              ),
            ]),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'SmartUp · v1.0.0',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _ink.withValues(alpha: 0.4),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'More',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Manage your school and app settings',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _ink.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _open(const AdminAnnouncementsScreen()),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: _ink, size: 24),
                ),
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFF5F5FB), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(String fullName, String schoolName) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _open(const AdminProfileScreen()),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7367F0), Color(0xFF5A4FD4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        schoolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: _ink.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Administrator',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: _ink.withValues(alpha: 0.3), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _menuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _menuTile(items[i], first: i == 0, last: i == items.length - 1),
            if (i < items.length - 1)
              const Divider(
                height: 1,
                indent: 66,
                endIndent: 16,
                color: Color(0xFFF0F1F6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _menuTile(_MenuItem it, {required bool first, required bool last}) {
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(20) : Radius.zero,
      bottom: last ? const Radius.circular(20) : Radius.zero,
    );
    final color = it.danger ? const Color(0xFFEF4444) : _ink;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: it.onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: it.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(it.icon, color: it.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      it.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: _ink.withValues(alpha: 0.25), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support'),
        content: const Text(
          'For billing, onboarding, or technical help contact your platform provider.\n\n'
          'Email: support@schoolplatform.demo\n'
          'Phone: +91 98765 43210',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
}
