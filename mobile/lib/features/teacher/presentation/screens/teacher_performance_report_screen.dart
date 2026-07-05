import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Combined student performance: rank by an overall score (70% marks + 30%
/// attendance) with marks% and attendance% shown per student.
class TeacherPerformanceReportScreen extends ConsumerStatefulWidget {
  const TeacherPerformanceReportScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherPerformanceReportScreen> createState() =>
      _TeacherPerformanceReportScreenState();
}

class _TeacherPerformanceReportScreenState
    extends ConsumerState<TeacherPerformanceReportScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();

  static const _rankColors = [
    Color(0xFFF59E0B),
    Color(0xFF94A3B8),
    Color(0xFFB45309),
  ];

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
      final res = await ref.read(dioProvider).get(
        '/teacher/reports/performance',
        queryParameters: {'classId': widget.classId},
      );
      if (!mounted) return;
      final list = ((res.data as Map)['students'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // Ranked first (by rank), then unranked (no data) at the bottom.
      list.sort((a, b) {
        final ra = (a['rank'] as num?)?.toInt();
        final rb = (b['rank'] as num?)?.toInt();
        if (ra == null && rb == null) {
          return ((a['rollNumber'] as num?) ?? 0)
              .compareTo((b['rollNumber'] as num?) ?? 0);
        }
        if (ra == null) return 1;
        if (rb == null) return -1;
        return ra.compareTo(rb);
      });
      setState(() {
        _students = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students
        .where((s) =>
            '${s['fullName'] ?? ''}'.toLowerCase().contains(q) ||
            '${s['rollNumber'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  int get _classAvg {
    final scored = _students
        .where((s) => s['score'] != null)
        .map((s) => (s['score'] as num).toInt())
        .toList();
    if (scored.isEmpty) return 0;
    return (scored.reduce((a, b) => a + b) / scored.length).round();
  }

  Color _scoreColor(int? v) {
    if (v == null) return AppColors.textMuted;
    if (v >= 75) return const Color(0xFF16A34A);
    if (v >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Student Performance', widget.classLabel),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  reportSummaryHero(
                    percent: _classAvg,
                    centerLabel: 'score',
                    title: 'Overall Performance',
                    pills: [
                      ('${_students.length}', 'Students'),
                      (
                        '${_students.where((s) => s['score'] != null).length}',
                        'Ranked'
                      ),
                      ('70/30', 'Marks/Att'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TeacherSearchField(
                    hint: 'Search student or roll',
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    showClear: _query.isNotEmpty,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_filtered.isEmpty)
                    reportEmptyState(
                      icon: Icons.insights_outlined,
                      searching: _query.isNotEmpty,
                      text:
                          'Performance ranks appear once marks and attendance are recorded.',
                    )
                  else
                    ..._filtered.map(_row),
                ],
              ),
            ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final rank = (s['rank'] as num?)?.toInt();
    final score = (s['score'] as num?)?.toInt();
    final marks = (s['marksPercent'] as num?)?.toInt();
    final att = (s['attendancePercent'] as num?)?.toInt();
    final color = _scoreColor(score);
    final isTop3 = rank != null && rank <= 3;
    final rankColor =
        isTop3 ? _rankColors[rank - 1] : const Color(0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: teacherCardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isTop3
                      ? rankColor.withValues(alpha: 0.15)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isTop3
                    ? Icon(Icons.emoji_events_rounded,
                        size: 15, color: rankColor)
                    : Text(
                        rank != null ? '$rank' : '–',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: rankColor),
                      ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Roll $roll',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score != null ? '$score' : '—',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1),
                  ),
                  const SizedBox(height: 2),
                  const Text('score',
                      style:
                          TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricChip(Icons.grade_rounded, 'Marks',
                  marks != null ? '$marks%' : '—', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _metricChip(Icons.fact_check_rounded, 'Attendance',
                  att != null ? '$att%' : '—', const Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}
