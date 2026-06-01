import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ParentProfileScreen extends ConsumerStatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  ConsumerState<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends ConsumerState<ParentProfileScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get('/parent/profile');
      setState(() => _profile = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final children = _profile?['children'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Manage your account and child information', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(user?['fullName']?[0] ?? 'P')),
            title: Text(user?['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Parent', style: TextStyle(color: AppColors.parentPrimary)),
                Text(user?['email'] ?? ''),
                Text(user?['phone'] ?? ''),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('My Children', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.parentPrimary)),
        ...children.map((c) {
          final link = c as Map<String, dynamic>;
          final st = link['student'] as Map<String, dynamic>;
          final cls = st['class'] as Map<String, dynamic>;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(st['fullName'][0])),
              title: Text(st['fullName']),
              subtitle: Text('Class ${cls['grade']}${cls['section']} • Roll ${st['rollNumber']}'),
              trailing: const Chip(label: Text('Active')),
            ),
          );
        }),
        ListTile(leading: const Icon(Icons.lock, color: AppColors.leaveOrange), title: const Text('Change Password')),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout'),
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
