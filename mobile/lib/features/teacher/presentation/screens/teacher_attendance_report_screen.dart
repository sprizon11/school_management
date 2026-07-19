import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Per-student attendance report: percentage, present/absent/leave counts,
/// with a class summary and sort/filter. Opened from the Reports screen.
class TeacherAttendanceReportScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceReportScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAttendanceReportScreen> createState() =>
      _TeacherAttendanceReportScreenState();
}

enum _Sort { rollAsc, percentDesc, percentAsc }

class _TeacherAttendanceReportScreenState
    extends ConsumerState<TeacherAttendanceReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _query = '';
  _Sort _sort = _Sort.rollAsc;
  final _searchCtrl = TextEditingController();

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
      final res = await ref
          .read(dioProvider)
          .get(
            '/teacher/reports/attendance',
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
    var list = q.isEmpty
        ? raw
        : raw
              .where(
                (s) =>
                    '${s['fullName'] ?? ''}'.toLowerCase().contains(q) ||
                    '${s['rollNumber'] ?? ''}'.toLowerCase().contains(q),
              )
              .toList();
    int pct(Map<String, dynamic> s) => (s['percent'] as num?)?.toInt() ?? -1;
    switch (_sort) {
      case _Sort.rollAsc:
        list.sort(
          (a, b) => ((a['rollNumber'] as num?) ?? 0).compareTo(
            (b['rollNumber'] as num?) ?? 0,
          ),
        );
      case _Sort.percentDesc:
        list.sort((a, b) => pct(b).compareTo(pct(a)));
      case _Sort.percentAsc:
        list.sort((a, b) => pct(a).compareTo(pct(b)));
    }
    return list;
  }

  Color _pctColor(int? pct) {
    if (pct == null) return AppColors.textMuted;
    if (pct >= 85) return _green;
    if (pct >= 75) return _amber;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: AppBar(
        backgroundColor: teacherBg,
        foregroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Report',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
                color: Color(0xFF1E1B4B),
              ),
            ),
            Text(
              widget.classLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TeacherSearchField(
                          hint: 'Search student or roll',
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          showClear: _query.isNotEmpty,
                          onClear: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      _sortButton(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_students.isEmpty)
                    _empty()
                  else
                    ..._students.map(_studentRow),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary hero
  // ---------------------------------------------------------------------
  Widget _summaryCard() {
    final avg = (_data?['classAverage'] as num?)?.toInt() ?? 0;
    final sessions = (_data?['totalSessions'] as num?)?.toInt() ?? 0;
    final leaves = (_data?['totalLeaves'] as num?)?.toInt() ?? 0;
    final absences = (_data?['totalAbsences'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(
                    value: (avg / 100).clamp(0.0, 1.0),
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$avg%',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'avg',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Attendance',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryPill('$sessions', 'Sessions'),
                    const SizedBox(width: 8),
                    _summaryPill('$leaves', 'Leaves'),
                    const SizedBox(width: 8),
                    _summaryPill('$absences', 'Absents'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sort button
  // ---------------------------------------------------------------------
  Widget _sortButton() {
    return PopupMenuButton<_Sort>(
      onSelected: (v) => setState(() => _sort = v),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Sort.rollAsc, child: Text('Roll number')),
        PopupMenuItem(
          value: _Sort.percentDesc,
          child: Text('Highest attendance'),
        ),
        PopupMenuItem(
          value: _Sort.percentAsc,
          child: Text('Lowest attendance'),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: const Icon(
          Icons.sort_rounded,
          color: AppColors.teacherPrimary,
          size: 22,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Student row
  // ---------------------------------------------------------------------
  Widget _studentRow(Map<String, dynamic> s) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final pct = (s['percent'] as num?)?.toInt();
    final present = (s['present'] as num?)?.toInt() ?? 0;
    final absent = (s['absent'] as num?)?.toInt() ?? 0;
    final leave = (s['leave'] as num?)?.toInt() ?? 0;
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final color = _pctColor(pct);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: teacherCardDecoration(),
      child: Column(
        children: [
          Row(
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
                    fontSize: 16,
                  ),
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
                      'Roll $roll · $total sessions',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pct != null ? '$pct%' : '—',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pct == null
                        ? 'no data'
                        : pct >= 85
                        ? 'Good'
                        : pct >= 75
                        ? 'Average'
                        : 'Low',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Attendance bar (present / leave / absent)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: total == 0
                  ? Container(color: const Color(0xFFEEF0F5))
                  : Row(
                      children: [
                        if (present > 0)
                          Expanded(
                            flex: present,
                            child: Container(color: _green),
                          ),
                        if (leave > 0)
                          Expanded(
                            flex: leave,
                            child: Container(color: _amber),
                          ),
                        if (absent > 0)
                          Expanded(
                            flex: absent,
                            child: Container(color: _red),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _legendCount(_green, 'Present', present),
              const SizedBox(width: 14),
              _legendCount(_amber, 'Leave', leave),
              const SizedBox(width: 14),
              _legendCount(_red, 'Absent', absent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendCount(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teacherPrimary.withValues(alpha: 0.08),
            ),
            child: Icon(
              _query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.event_available_outlined,
              size: 40,
              color: AppColors.teacherPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _query.isNotEmpty ? 'No students found' : 'No students yet',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Attendance percentages appear here once students are added and attendance is marked.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
