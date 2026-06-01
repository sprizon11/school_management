import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_shell.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const AdminHeader(title: 'More', subtitle: 'Settings & tools'),
        ListTile(leading: const Icon(Icons.campaign), title: const Text('Announcements'), onTap: () {}),
        ListTile(leading: const Icon(Icons.payments), title: const Text('Fee Management'), onTap: () {}),
        ListTile(leading: const Icon(Icons.assessment), title: const Text('Reports'), onTap: () {}),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout'),
          onTap: () => adminLogout(ref, context),
        ),
      ],
    );
  }
}
