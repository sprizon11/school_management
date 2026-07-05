import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_add_marks_screen.dart';

/// Per-student marks report with class average, pass rate, and an expandable
/// subject-wise breakdown per student.
class TeacherMarksReportScreen extends ConsumerStatefulWidget {
  const TeacherMarksReportScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherMarksReportScreen> createState() =>
      _TeacherMarksReportScreenState();
}

class _TeacherMarksReportScreenState
    extends ConsumerState<TeacherMarksReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _expanded = <String>{};

  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

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
        '/teacher/reports/marks',
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

  List<Map<String, dynamic>> get _students {
    final raw = (_data?['students'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return raw;
    return raw
        .where((s) =>
            '${s['fullName'] ?? ''}'.toLowerCase().contains(q) ||
            '${s['rollNumber'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openAddMarks() async {
    final saved = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        page: TeacherAddMarksScreen(
          classId: widget.classId,
          classLabel: widget.classLabel,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Color _pctColor(int? pct) {
    if (pct == null) return AppColors.textMuted;
    if (pct >= 75) return _green;
    if (pct >= 35) return _amber;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Marks Report', widget.classLabel),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMarks,
        backgroundColor: AppColors.teacherPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Marks'),
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
                  _summary(),
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
                  if (_students.isEmpty)
                    reportEmptyState(
                      icon: Icons.assignment_outlined,
                      searching: _query.isNotEmpty,
                      text:
                          'Marks appear here once exams are graded for this class.',
                    )
                  else
                    ..._students.map(_studentCard),
                ],
              ),
            ),
    );
  }

  Widget _summary() {
    final avg = (_data?['classAverage'] as num?)?.toInt() ?? 0;
    final passRate = (_data?['passRate'] as num?)?.toInt() ?? 0;
    final graded = (_data?['gradedCount'] as num?)?.toInt() ?? 0;
    return reportSummaryHero(
      percent: avg,
      centerLabel: 'avg',
      title: 'Class Average',
      pills: [
        ('$passRate%', 'Pass Rate'),
        ('$graded', 'Graded'),
        ('${_students.length}', 'Students'),
      ],
    );
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final id = '${s['id']}';
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final pct = (s['percent'] as num?)?.toInt();
    final subjects = s['subjects'] as List<dynamic>? ?? [];
    final color = _pctColor(pct);
    final open = _expanded.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: teacherCardDecoration(),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(teacherCardRadius),
            onTap: subjects.isEmpty
                ? null
                : () => setState(() =>
                    open ? _expanded.remove(id) : _expanded.add(id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
                        Text(
                          subjects.isEmpty
                              ? 'Roll $roll · no marks'
                              : 'Roll $roll · ${subjects.length} subjects',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    pct != null ? '$pct%' : '—',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (subjects.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (open && subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF0F1F6)),
                  const SizedBox(height: 8),
                  for (final sub in subjects)
                    _subjectRow(sub as Map<String, dynamic>),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _subjectRow(Map<String, dynamic> sub) {
    final marks = (sub['marks'] as num?)?.toInt() ?? 0;
    final max = (sub['maxMarks'] as num?)?.toInt() ?? 100;
    final pct = max > 0 ? (marks / max * 100).round() : 0;
    final color = _pctColor(pct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${sub['name'] ?? 'Subject'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 6, color: const Color(0xFFEEF0F5)),
                  FractionallySizedBox(
                    widthFactor: (pct / 100).clamp(0.0, 1.0),
                    child: Container(height: 6, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '$marks/$max',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
          ),
          if ('${sub['grade'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${sub['grade']}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
