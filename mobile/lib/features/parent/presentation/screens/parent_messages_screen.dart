import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../teacher/presentation/screens/chat_thread_screen.dart';

/// Teacher conversations. Lifted out of ParentShell unchanged when the shell
/// gained a Home tab.
class ParentMessagesScreen extends ConsumerStatefulWidget {
  const ParentMessagesScreen({super.key});

  @override
  ConsumerState<ParentMessagesScreen> createState() =>
      _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends ConsumerState<ParentMessagesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/parent/chat/conversations');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeLabel(dynamic raw) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    // The shell has no AppBar (Home draws its own header), so this screen
    // owns its title and top inset.
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        8,
      ),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Messages',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1533),
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

    if (_loading) {
      return Column(
        children: [
          header,
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.parentPrimary),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() {
    final user = ref.watch(authProvider).user;

    return RefreshIndicator(
      color: AppColors.parentPrimary,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Hi ${user?.fullName ?? 'Parent'},\nno teacher chat yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              // Extra bottom room so the floating nav never covers a row.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _items[i] as Map<String, dynamic>;
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.parentPrimary.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      '${c['teacherName'] ?? 'T'}'[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.parentPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    '${c['teacherName']}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${c['studentName']} · Class ${c['classLabel']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: c['lastMessageAt'] != null
                      ? Text(
                          _timeLabel(c['lastMessageAt']),
                          style: const TextStyle(fontSize: 10),
                        )
                      : null,
                  onTap: () async {
                    await Navigator.of(context).push(
                      SmoothPageRoute(
                        page: ChatThreadScreen(
                          conversationId: '${c['id']}',
                          apiPrefix: '/parent/chat',
                          title: '${c['teacherName']}',
                          subtitle:
                              '${c['studentName']} · ${c['subject'] ?? 'Class teacher'}',
                        ),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
    );
  }
}
