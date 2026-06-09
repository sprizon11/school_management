import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/notification_poller.dart';
import '../../../../core/theme/app_colors.dart';
import 'teacher_announcements_screen.dart';

class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final user = ref.watch(authProvider.select((a) => a.user));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.campaign_rounded, color: AppColors.teacherPrimary),
          title: const Text('Announcements'),
          subtitle: const Text('Messages from school admin'),
          trailing: unread > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Text(
                    '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            SmoothPageRoute(page: const TeacherAnnouncementsScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person_outline, color: AppColors.teacherPrimary),
          title: Text(user?.fullName ?? 'Teacher'),
          subtitle: Text(user?.email ?? ''),
        ),
      ],
    );
  }
}
