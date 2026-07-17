import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _items = [];
  bool _loading = true;
  bool _sending = false;
  String _audience = 'TEACHERS';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/announcements');
      _items = res.data as List<dynamic>? ?? [];
    } catch (_) {
      _items = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;

    setState(() => _sending = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '/admin/announcements',
            data: {'title': title, 'body': text, 'audience': _audience},
          );
      _messageController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement sent. Teachers will be notified.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(dynamic value) {
    final dt = DateTime.tryParse('$value');
    if (dt == null) return '';
    return DateFormat('d MMM, h:mm a').format(dt.toLocal());
  }

  String _audienceLabel(String? value) {
    if (value == 'TEACHERS_AND_PARENTS') return 'Teachers & parents';
    return 'Teachers only';
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubPageScaffold(
      title: 'Announcements',
      subtitle: 'Broadcast to teachers & parents',
      child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'No announcements yet.\nSend your first message below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i] as Map<String, dynamic>;
                      return _chatBubble(item);
                    },
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _chatBubble(Map<String, dynamic> item) {
    final body = '${item['body'] ?? ''}';
    final postedBy = '${item['postedBy'] ?? 'Admin'}';
    final time = _formatTime(item['createdAt']);
    final audience = _audienceLabel(item['audience'] as String?);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0835B8), Color(0xFF1B5FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    audience,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$postedBy · $time',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _audienceChip('TEACHERS', 'Teachers only'),
              const SizedBox(width: 8),
              _audienceChip('TEACHERS_AND_PARENTS', 'Teachers & parents'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type announcement…',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _sending ? null : _send,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 48,
                    width: 48,
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(String value, String label) {
    final selected = _audience == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _audience = value),
      selectedColor: AppColors.primary.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
      ),
    );
  }
}
