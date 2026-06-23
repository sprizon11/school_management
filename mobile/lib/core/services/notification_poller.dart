import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../providers/auth_provider.dart';

final unreadNotificationCountProvider = StateProvider<int>((ref) => 0);

class NotificationPoller extends ConsumerStatefulWidget {
  const NotificationPoller({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationPoller> createState() => _NotificationPollerState();
}

class _NotificationPollerState extends ConsumerState<NotificationPoller>
    with WidgetsBindingObserver {
  final Set<String> _seenIds = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
    }
  }

  Future<void> _poll() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.user?.role != 'TEACHER') return;

    try {
      final dio = ref.read(dioProvider);
      final countRes = await dio.get('/teacher/notifications/unread-count');
      final count = (countRes.data as num?)?.toInt() ?? 0;
      ref.read(unreadNotificationCountProvider.notifier).state = count;

      final listRes = await dio.get('/teacher/notifications');
      final items = listRes.data as List<dynamic>? ?? [];

      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final id = '${item['id']}';
        if (id.isEmpty || _seenIds.contains(id)) continue;
        if (item['readAt'] != null) {
          _seenIds.add(id);
          continue;
        }

        _seenIds.add(id);
        if (!mounted) return;

        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text('${item['title'] ?? 'New notification'}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {},
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        break;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
