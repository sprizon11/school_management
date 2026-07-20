import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../widgets/teacher_ui.dart';

class TeacherAnnouncementsScreen extends ConsumerStatefulWidget {
  const TeacherAnnouncementsScreen({super.key});

  @override
  ConsumerState<TeacherAnnouncementsScreen> createState() =>
      _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState
    extends ConsumerState<TeacherAnnouncementsScreen> {
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
      final res = await ref.read(dioProvider).get('/teacher/announcements');
      _items = res.data as List<dynamic>? ?? [];
      await ref.read(dioProvider).patch('/teacher/notifications/read-all');
    } catch (_) {
      _items = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _formatTime(dynamic value) {
    final dt = DateTime.tryParse('$value');
    if (dt == null) return '';
    return DateFormat('d MMM, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: Color(0xFF1E1B4B),
          ),
        ),
        backgroundColor: teacherBg,
        foregroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherPrimary,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.campaign_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'No announcements from admin yet.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        final isLatest = i == _items.length - 1;
                        return EntranceFadeItem(
                          index: i,
                          child: _announcementCard(item, isLatest),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _announcementCard(Map<String, dynamic> item, bool isLatest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: teacherCardDecoration().copyWith(
        border: isLatest
            ? Border.all(color: AppColors.teacherPrimary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLatest)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B58),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LATEST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Text(
            '${item['body'] ?? ''}',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '${item['postedBy'] ?? 'Admin'} · ${_formatTime(item['createdAt'])}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
