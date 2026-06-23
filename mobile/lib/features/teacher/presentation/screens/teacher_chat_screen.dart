import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';
import 'chat_thread_screen.dart';

class TeacherChatScreen extends ConsumerStatefulWidget {
  const TeacherChatScreen({super.key});

  @override
  ConsumerState<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends ConsumerState<TeacherChatScreen> {
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
      final res = await ref.read(dioProvider).get('/teacher/chat/conversations');
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
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('h:mm a').format(dt.toLocal());
    }
    return DateFormat('d MMM').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          const TeacherPageHeader(
            title: 'Messages',
            subtitle: 'Chat with parents',
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.teacherPrimary,
                      child: _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 80),
                                Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textMuted),
                                SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'No parent chats yet.\nAdd students to start messaging.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textMuted),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: _items.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final c = _items[i] as Map<String, dynamic>;
                                final unread = (c['unread'] as num?)?.toInt() ?? 0;
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        SmoothPageRoute(
                                          page: ChatThreadScreen(
                                            conversationId: '${c['id']}',
                                            apiPrefix: '/teacher/chat',
                                            title: '${c['parentName']}',
                                            subtitle:
                                                '${c['studentName']} · Class ${c['classLabel']}',
                                          ),
                                        ),
                                      );
                                      _load();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundColor:
                                                AppColors.teacherPrimary.withValues(alpha: 0.12),
                                            child: Text(
                                              '${c['parentName'] ?? 'P'}'[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.teacherPrimary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${c['parentName']}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${c['studentName']} · Class ${c['classLabel']}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                                if (c['lastMessage'] != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${c['lastMessage']}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: unread > 0
                                                          ? const Color(0xFF111827)
                                                          : AppColors.textMuted,
                                                      fontWeight: unread > 0
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              if (c['lastMessageAt'] != null)
                                                Text(
                                                  _timeLabel(c['lastMessageAt']),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              if (unread > 0) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.teacherPrimary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '$unread',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
