import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_add_assignment_screen.dart';

/// Assignment report: lists homework assigned to the class, split into
/// upcoming and past, with due dates.
class TeacherAssignmentsReportScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentsReportScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAssignmentsReportScreen> createState() =>
      _TeacherAssignmentsReportScreenState();
}

class _TeacherAssignmentsReportScreenState
    extends ConsumerState<TeacherAssignmentsReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/teacher/reports/assignments',
        queryParameters: {'classId': widget.classId},
      );
      if (!mounted) return;
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateLabel(dynamic raw) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return '';
    return DateFormat('d MMM yyyy').format(dt.toLocal());
  }

  Future<void> _openAddAssignment() async {
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        page: TeacherAddAssignmentScreen(
          classId: widget.classId,
          classLabel: widget.classLabel,
        ),
      ),
    );
    if (added == true) _load();
  }

  int _daysDiff(dynamic raw) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return 0;
    final now = DateTime.now();
    return DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final items = (_data?['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final upcoming = items.where((h) => h['status'] == 'upcoming').toList();
    final past = items.where((h) => h['status'] == 'past').toList();

    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Assignment Report', widget.classLabel),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAssignment,
        backgroundColor: AppColors.teacherPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Assignment'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _summary(items.length, upcoming.length, past.length),
                  const SizedBox(height: 20),
                  if (items.isEmpty)
                    reportEmptyState(
                      icon: Icons.assignment_turned_in_outlined,
                      searching: false,
                      text:
                          'Homework you assign to this class will be listed here.',
                    )
                  else ...[
                    if (upcoming.isNotEmpty) ...[
                      _sectionTitle('Upcoming', upcoming.length, _orange),
                      const SizedBox(height: 10),
                      ...upcoming.map((h) => _assignmentCard(h, true)),
                      const SizedBox(height: 12),
                    ],
                    if (past.isNotEmpty) ...[
                      _sectionTitle('Past', past.length, AppColors.textMuted),
                      const SizedBox(height: 10),
                      ...past.map((h) => _assignmentCard(h, false)),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summary(int total, int upcoming, int past) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B7BFF), Color(0xFF5B4EE9), Color(0xFF3B2FBE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _bigStat('$total', 'Total'),
          _divider(),
          _bigStat('$upcoming', 'Upcoming'),
          _divider(),
          _bigStat('$past', 'Past'),
        ],
      ),
    );
  }

  Widget _bigStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.18),
      );

  Widget _sectionTitle(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    );
  }

  Widget _assignmentCard(Map<String, dynamic> h, bool upcoming) {
    final title = '${h['title'] ?? 'Assignment'}';
    final desc = '${h['description'] ?? ''}';
    final days = _daysDiff(h['dueDate']);
    final color = upcoming ? _orange : AppColors.textMuted;

    String dueTag;
    if (upcoming) {
      dueTag = days == 0
          ? 'Due today'
          : days == 1
              ? 'Due tomorrow'
              : 'In $days days';
    } else {
      dueTag = 'Ended';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: teacherCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_rounded, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.25,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted, height: 1.3),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _dateLabel(h['dueDate']),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dueTag,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color,
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
    );
  }
}
