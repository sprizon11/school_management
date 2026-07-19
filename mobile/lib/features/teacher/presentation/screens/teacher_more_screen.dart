import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/notification_poller.dart';
import '../../../../core/theme/app_colors.dart';
import 'teacher_announcements_screen.dart';
import '../widgets/teacher_ui.dart';

class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final user = ref.watch(authProvider.select((a) => a.user));

    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          TeacherPlainHeader(
            title: 'More',
            subtitle: user?.email ?? '',
            trailing: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                (user?.fullName ?? '').isNotEmpty
                    ? user!.fullName[0].toUpperCase()
                    : 'T',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset.zero,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: teacherCardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [teacherHeaderStart, teacherHeaderEnd],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'Teacher',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.schoolName ?? 'SmartUp',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: teacherCardDecoration(),
                    child: Column(
                      children: [
                        TeacherMenuTile(
                          icon: Icons.campaign_rounded,
                          title: 'Announcements',
                          subtitle: 'Messages from school admin',
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread new',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(context).push(
                            SmoothPageRoute(
                              page: const TeacherAnnouncementsScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 68, endIndent: 14),
                        TeacherMenuTile(
                          icon: Icons.email_outlined,
                          title: 'Account email',
                          subtitle: user?.email ?? '',
                          trailing: const SizedBox.shrink(),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: teacherCardDecoration(),
                    child: TeacherMenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      subtitle: 'Log out of your teacher account',
                      destructive: true,
                      trailing: const SizedBox.shrink(),
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
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
}
