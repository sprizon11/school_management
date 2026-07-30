import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Parent notifications — chat messages from teachers and school announcements.
/// Opening the screen marks everything read.
class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends ConsumerState<ParentNotificationsScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;

  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _items.isEmpty);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/parent/notifications');
      // Seeing the list clears the unread state.
      await dio.patch('/parent/notifications/read-all');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('message')) return Icons.chat_bubble_rounded;
    return Icons.campaign_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 90),
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 46,
                          color: _accent.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => EntranceFadeItem(
                        index: i,
                        child: _row(
                          Map<String, dynamic>.from(_items[i] as Map),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _row(Map<String, dynamic> n) {
    final title = '${n['title'] ?? ''}';
    final body = '${n['body'] ?? ''}';
    final created = DateTime.tryParse('${n['createdAt'] ?? ''}');
    final when = created == null
        ? ''
        : DateFormat('d MMM · h:mm a').format(created.toLocal());
    final unread = n['readAt'] == null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? _accent.withValues(alpha: 0.3) : const Color(0xFFEFEFF6),
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(title), size: 20, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ink.withValues(alpha: 0.6),
                      height: 1.35,
                    ),
                  ),
                ],
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 11,
                      color: _ink.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (unread)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              height: 8,
              width: 8,
              decoration: const BoxDecoration(
                color: AppColors.statOrange,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
