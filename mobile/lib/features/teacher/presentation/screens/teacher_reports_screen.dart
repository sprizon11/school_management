import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_add_marks_screen.dart';
import 'teacher_assignments_report_screen.dart';
import 'teacher_attendance_report_screen.dart';
import 'teacher_marks_report_screen.dart';
import 'teacher_performance_report_screen.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  ConsumerState<TeacherReportsScreen> createState() =>
      _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _classInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classes = await ref.read(dioProvider).get('/teacher/classes');
      final list = classes.data as List<dynamic>? ?? [];
      if (list.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final first = list.first as Map<String, dynamic>;
      final res = await ref
          .read(dioProvider)
          .get(
            '/teacher/reports/overview',
            queryParameters: {'classId': first['id']},
          );
      if (!mounted) return;
      setState(() {
        _classInfo = first;
        _overview = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.teacherPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _pct(dynamic raw) {
    final v = double.tryParse('$raw') ?? 0;
    return (v / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Three states, not two. Previously a teacher with no class fell through
    // to a page showing only the four report tiles floating on empty space,
    // with nothing explaining why the analytics were missing.
    final hasClass = _classInfo != null;

    final body = ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.teacherPrimary,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.teacherPrimary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        if (!hasClass) ...[
                          const EntranceFade(child: _NoClassNotice()),
                          const SizedBox(height: 20),
                        ] else ...[
                          EntranceFade(child: _performanceCard()),
                          const SizedBox(height: 20),
                          EntranceFade(
                            delay: const Duration(milliseconds: 70),
                            child: _leaderboard(
                              title: 'Top Students',
                              icon: Icons.emoji_events_rounded,
                              items:
                                  _overview!['topStudents'] as List<dynamic>? ??
                                  const [],
                              valueKey: 'avgMarks',
                              accent: const Color(0xFFF59E0B),
                              emptyText:
                                  'No marks recorded yet — rankings appear once exams are graded.',
                            ),
                          ),
                          const SizedBox(height: 20),
                          EntranceFade(
                            delay: const Duration(milliseconds: 140),
                            child: _leaderboard(
                              title: 'Best Attendance',
                              icon: Icons.verified_rounded,
                              items:
                                  _overview!['topAttendance']
                                      as List<dynamic>? ??
                                  const [],
                              valueKey: 'attendancePercent',
                              accent: AppColors.statGreen,
                              emptyText:
                                  'No attendance records yet — rankings appear once attendance is marked.',
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        EntranceFade(
                          delay: Duration(milliseconds: hasClass ? 210 : 70),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TeacherSectionTitle('Report Types'),
                              _reportGrid(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );

    // Recording marks is a write action, so it gets a FAB rather than hiding
    // behind the Marks *report* two screens down. No class means nothing to
    // grade, so the button stays off.
    if (!hasClass) return body;
    return TeacherFabScaffold(
      fab: TeacherFab(
        icon: Icons.post_add_rounded,
        tooltip: 'Enter marks',
        onTap: _openAddMarks,
      ),
      child: body,
    );
  }

  Future<void> _openAddMarks() async {
    if (_classInfo == null) return;
    final saved = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        page: TeacherAddMarksScreen(
          classId: '${_classInfo!['id']}',
          classLabel: 'Class ${_classInfo!['grade']}${_classInfo!['section']}',
        ),
      ),
    );
    if (saved == true) _load();
  }

  /// The four report tiles. Kept as one builder so the grid spacing lives in
  /// a single place.
  Widget _reportGrid() {
    final tiles =
        <
          ({
            IconData icon,
            Color color,
            String title,
            String sub,
            VoidCallback tap,
          })
        >[
          (
            icon: Icons.calendar_month_rounded,
            color: AppColors.statGreen,
            title: 'Attendance',
            sub: 'Per-student %',
            tap: _openAttendanceReport,
          ),
          (
            icon: Icons.assignment_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Marks',
            sub: 'Subject grades',
            tap: () => _openReport(
              (id, label) =>
                  TeacherMarksReportScreen(classId: id, classLabel: label),
            ),
          ),
          (
            icon: Icons.insights_rounded,
            color: AppColors.statPurple,
            title: 'Performance',
            sub: 'Marks + attendance',
            tap: () => _openReport(
              (id, label) => TeacherPerformanceReportScreen(
                classId: id,
                classLabel: label,
              ),
            ),
          ),
          (
            icon: Icons.task_alt_rounded,
            color: AppColors.statOrange,
            title: 'Assignments',
            sub: 'Homework & due dates',
            tap: () => _openReport(
              (id, label) => TeacherAssignmentsReportScreen(
                classId: id,
                classLabel: label,
              ),
            ),
          ),
        ];

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 12),
                Expanded(
                  child: EntranceFadeItem(
                    index: row * 2 + col,
                    child: _reportCard(
                      icon: tiles[row * 2 + col].icon,
                      color: tiles[row * 2 + col].color,
                      title: tiles[row * 2 + col].title,
                      subtitle: tiles[row * 2 + col].sub,
                      onTap: tiles[row * 2 + col].tap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Header — plain style (shared)
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    final classLabel = _classInfo != null
        ? 'Class ${_classInfo!['grade']}${_classInfo!['section']}'
        : null;

    return TeacherPlainHeader(
      title: 'Reports',
      subtitle: classLabel != null
          ? '$classLabel · Performance & analytics'
          : 'Performance & analytics',
      trailing: _overview != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    color: AppColors.teacherPrimary,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_overview!['totalStudents']}',
                    style: const TextStyle(
                      color: AppColors.teacherPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------
  // Class performance hero
  // ---------------------------------------------------------------------
  Widget _performanceCard() {
    final metrics =
        <({String label, dynamic value, Color color, IconData icon})>[
          (
            label: 'Attendance',
            value: _overview!['averageAttendance'],
            color: const Color(0xFF34D399),
            icon: Icons.fact_check_rounded,
          ),
          (
            label: 'Avg Marks',
            value: _overview!['classAverageMarks'],
            color: const Color(0xFFFBBF24),
            icon: Icons.grade_rounded,
          ),
          (
            label: 'Pass Rate',
            value: _overview!['passPercentage'],
            color: const Color(0xFF93C5FD),
            icon: Icons.trending_up_rounded,
          ),
        ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Class Performance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _metricBar(metrics[i]),
          ],
        ],
      ),
    );
  }

  Widget _metricBar(
    ({String label, dynamic value, Color color, IconData icon}) m,
  ) {
    final pct = _pct(m.value);
    return Row(
      children: [
        Icon(m.icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: Text(
            m.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                FractionallySizedBox(
                  widthFactor: pct == 0 ? 0.02 : pct,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: m.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${m.value}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Leaderboards — top students by marks / attendance
  // ---------------------------------------------------------------------
  static const _rankColors = [
    Color(0xFFF59E0B), // gold
    Color(0xFF94A3B8), // silver
    Color(0xFFB45309), // bronze
  ];

  Widget _leaderboard({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required String valueKey,
    required Color accent,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: accent),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: teacherCardDecoration(),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          emptyText,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 60,
                          color: Color(0xFFF0F1F6),
                        ),
                      _rankRow(
                        items[i] as Map<String, dynamic>,
                        i,
                        valueKey,
                        accent,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _rankRow(
    Map<String, dynamic> s,
    int rank,
    String valueKey,
    Color accent,
  ) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final value = s[valueKey];
    final isTop3 = rank < 3;
    final rankColor = isTop3 ? _rankColors[rank] : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isTop3
                  ? rankColor.withValues(alpha: 0.15)
                  : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isTop3
                ? Icon(Icons.emoji_events_rounded, size: 14, color: rankColor)
                : Text(
                    '${rank + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: rankColor,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
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
                fontSize: 14,
              ),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll $roll',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$value%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Report type cards — 2×2 colorful grid
  // ---------------------------------------------------------------------
  void _openAttendanceReport() => _openReport(
    (id, label) =>
        TeacherAttendanceReportScreen(classId: id, classLabel: label),
  );

  void _openReport(Widget Function(String classId, String classLabel) build) {
    if (_classInfo == null) return;
    Navigator.of(context).push(
      SmoothPageRoute(
        page: build(
          '${_classInfo!['id']}',
          'Class ${_classInfo!['grade']}${_classInfo!['section']}',
        ),
      ),
    );
  }

  Widget _reportCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return PressableScale(
      onTap: onTap ?? () => _comingSoon('$title report'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the signed-in teacher isn't a class teacher for any class.
///
/// Without this the screen rendered only the four report tiles on an
/// otherwise blank page, with nothing to explain why the analytics were
/// missing — it read as broken rather than as "nothing assigned yet".
class _NoClassNotice extends StatelessWidget {
  const _NoClassNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.teacherPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.teacherPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.teacherPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No class assigned yet',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Class analytics — attendance, marks and rankings — appear here '
            'once your school admin makes you a class teacher.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: const Color(0xFF111827).withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
