import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/teacher_announcements_screen.dart';
import '../screens/teacher_classes_screen.dart';

/// Slide-out panel for the teacher app.
///
/// Mirrors [AdminSidebar] in structure so both roles navigate the same way,
/// but in the teacher purple and listing the teacher's own tabs. Lives on the
/// shell's Scaffold so every tab can open it via `Scaffold.of(context)`.
class TeacherSidebar extends ConsumerWidget {
  const TeacherSidebar({super.key, this.onTabSelect});

  final ValueChanged<int>? onTabSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((a) => a.user));
    final fullName = user?.fullName ?? 'Teacher';
    final email = user?.email ?? '';

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
                    icon: Icons.home_rounded,
                    label: 'Dashboard',
                    color: AppColors.teacherPrimary,
                    onTap: () => _goTab(context, 0),
                  ),
                  _item(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    color: const Color(0xFF4F6FFF),
                    onTap: () => _goTab(context, 1),
                  ),
                  _item(
                    icon: Icons.people_alt_rounded,
                    label: 'Students',
                    color: const Color(0xFF3CCB6F),
                    onTap: () => _goTab(context, 2),
                  ),
                  _item(
                    icon: Icons.insert_chart_rounded,
                    label: 'Reports',
                    color: const Color(0xFFF5A623),
                    onTap: () => _goTab(context, 3),
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Updates'),
                  _item(
                    icon: Icons.campaign_rounded,
                    label: 'Announcements',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      openSmoothPage(
                        context,
                        const TeacherAnnouncementsScreen(),
                      );
                    },
                  ),
                  _item(
                    icon: Icons.menu_book_rounded,
                    label: 'My Classes',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      Navigator.pop(context);
                      openSmoothPage(context, const TeacherClassesScreen());
                    },
                  ),
                  const SizedBox(height: 8),
                  _sectionLabel('Account'),
                  _item(
                    icon: Icons.grid_view_rounded,
                    label: 'More',
                    color: const Color(0xFF64748B),
                    onTap: () => _goTab(context, 4),
                  ),
                  _item(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authProvider.notifier).logout();
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

  Widget _profileHeader(BuildContext context, String fullName, String email) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C3FD8), Color(0xFF635BFF), Color(0xFF8B7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
      ),
      child: Row(
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
              color: AppColors.teacherPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
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

  Widget _item({
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
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
