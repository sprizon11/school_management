import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';
import 'chat_thread_screen.dart';

/// WhatsApp-style parent messaging list. The backend returns one row per
/// student in the teacher's classes (auto-creating a conversation), so this
/// shows every parent the teacher can message — searchable, with last-message
/// preview, time, and unread badges.
class TeacherChatScreen extends ConsumerStatefulWidget {
  const TeacherChatScreen({super.key});

  @override
  ConsumerState<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends ConsumerState<TeacherChatScreen> {
  static const _wa = Color(0xFF25D366); // WhatsApp-green accent for unread
  static const _avatarPalette = [
    AppColors.teacherPrimary,
    Color(0xFF0EA5E9),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
  ];

  List<dynamic> _items = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = _items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (q.isEmpty) return list;
    return list.where((c) {
      final p = '${c['parentName'] ?? ''}'.toLowerCase();
      final s = '${c['studentName'] ?? ''}'.toLowerCase();
      return p.contains(q) || s.contains(q);
    }).toList();
  }

  int get _unreadTotal => _items.fold<int>(
        0,
        (sum, e) => sum + (((e as Map)['unread'] as num?)?.toInt() ?? 0),
      );

  String _timeLabel(dynamic raw) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(local);
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(local);
  }

  Color _avatarColor(Map<String, dynamic> c) {
    final key = '${c['parentName'] ?? c['id'] ?? ''}';
    final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarPalette[hash % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.teacherPrimary),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.teacherPrimary,
                    child: _filtered.isEmpty
                        ? _emptyState()
                        : _conversationList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header — plain style (matches Reports)
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    final count = _items.length;

    return TeacherPlainHeader(
      icon: Icons.forum_rounded,
      title: 'Messages',
      subtitle: _loading
          ? 'Chat with parents'
          : _unreadTotal > 0
              ? '$count chats · $_unreadTotal unread'
              : '$count ${count == 1 ? 'parent chat' : 'parent chats'}',
      trailing: _unreadTotal > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _wa,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_unreadTotal new',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      bottomChild: TeacherSearchField(
        hint: 'Search parents or students',
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        showClear: _query.isNotEmpty,
        onClear: () {
          _searchCtrl.clear();
          setState(() => _query = '');
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Conversation list — WhatsApp-style rows
  // ---------------------------------------------------------------------
  Widget _conversationList() {
    final list = _filtered;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: list.length,
      separatorBuilder: (_, index) => const Padding(
        padding: EdgeInsets.only(left: 78),
        child: Divider(height: 1, color: Color(0xFFEDEFF5)),
      ),
      itemBuilder: (_, i) => _conversationTile(list[i]),
    );
  }

  Widget _conversationTile(Map<String, dynamic> c) {
    final unread = (c['unread'] as num?)?.toInt() ?? 0;
    final hasUnread = unread > 0;
    final parentName = '${c['parentName'] ?? 'Parent'}';
    final studentName = '${c['studentName'] ?? ''}';
    final classLabel = '${c['classLabel'] ?? ''}';
    final lastMessage = c['lastMessage'];
    final color = _avatarColor(c);

    final preview = lastMessage != null && '$lastMessage'.trim().isNotEmpty
        ? '$lastMessage'
        : 'Parent of $studentName · Class $classLabel';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            SmoothPageRoute(
              page: ChatThreadScreen(
                conversationId: '${c['id']}',
                apiPrefix: '/teacher/chat',
                title: parentName,
                subtitle: '$studentName · Class $classLabel',
              ),
            ),
          );
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  parentName.isNotEmpty ? parentName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            parentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: const Color(0xFF111827),
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (c['lastMessageAt'] != null)
                          Text(
                            _timeLabel(c['lastMessageAt']),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
                              color: hasUnread ? _wa : AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (lastMessage == null ||
                            '$lastMessage'.trim().isEmpty) ...[
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              color: hasUnread
                                  ? const Color(0xFF111827)
                                  : AppColors.textMuted,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasUnread)
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _wa,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------
  Widget _emptyState() {
    final searching = _query.trim().isNotEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teacherPrimary.withValues(alpha: 0.08),
            ),
            child: Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.forum_outlined,
              size: 44,
              color: AppColors.teacherPrimary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            searching ? 'No matches found' : 'No parent chats yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            searching
                ? 'Try a different parent or student name.'
                : 'Once students are added to your classes, their parents will appear here to chat with.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
