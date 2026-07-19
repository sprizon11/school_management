import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/notification_poller.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/teacher_shell_provider.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_announcements_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_classes_screen.dart';

const _dashBg = Color(0xFFF8F9FE);
const _headerPurple = Color(0xFF1E1B4B);
const _hPad = 16.0;

BoxDecoration _premiumCard({Color? color, Border? border}) => BoxDecoration(
  color: color ?? Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: border,
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF5C59E8).withValues(alpha: 0.07),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ],
);

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  Map<String, dynamic>? _data;
  List<dynamic> _schedule = [];

  /// Today's periods, kept separately so the hero card stays on "today"
  /// even when the timetable day chips are switched to another day.
  List<dynamic> _todaySchedule = [];
  List<dynamic> _classes = [];
  List<dynamic> _homework = [];
  bool _loading = true;
  bool _scheduleLoading = false;

  /// Compact timetable shows the first few periods; toggles to full list.
  bool _showAllPeriods = false;
  final GlobalKey _timetableKey = GlobalKey();

  /// Selected weekday in JS convention (0=Sun … 6=Sat) to match the API.
  /// Defaults to today; Sundays fall back to Monday since it's a holiday.
  late int _selectedDay;

  static int get _todayIndex => DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _selectedDay = _todayIndex == 0 ? 1 : _todayIndex;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final summary = await dio.get('/teacher/dashboard/summary');
      final schedule = await dio.get(
        '/teacher/dashboard/schedule',
        queryParameters: {'day': _selectedDay},
      );
      final classes = await dio.get('/teacher/classes');
      List<dynamic> homework = [];
      try {
        final hw = await dio.get('/teacher/homework/upcoming');
        homework = hw.data as List<dynamic>? ?? [];
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = summary.data as Map<String, dynamic>;
        _schedule = schedule.data as List<dynamic>? ?? [];
        // Sunday is a holiday: today's list stays empty when we defaulted to Monday.
        _todaySchedule = _selectedDay == _todayIndex ? _schedule : <dynamic>[];
        _classes = classes.data as List<dynamic>? ?? [];
        _homework = homework;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDay(int day) async {
    if (day == _selectedDay && !_scheduleLoading) return;
    setState(() {
      _selectedDay = day;
      _scheduleLoading = true;
      _showAllPeriods = false;
    });
    try {
      final res = await ref
          .read(dioProvider)
          .get('/teacher/dashboard/schedule', queryParameters: {'day': day});
      if (!mounted || _selectedDay != day) return;
      setState(() {
        _schedule = res.data as List<dynamic>? ?? [];
        if (day == _todayIndex) _todaySchedule = _schedule;
        _scheduleLoading = false;
      });
    } catch (_) {
      if (mounted && _selectedDay == day) {
        setState(() => _scheduleLoading = false);
      }
    }
  }

  Future<void> _openTimetableEditor() async {
    final dayLabel = _dayChips.firstWhere((c) => c.day == _selectedDay).label;
    final classOptions = <String>{
      for (final c in _classes)
        'Class ${(c as Map<String, dynamic>)['grade']}${c['section']}',
    }.toList();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimetableEditorSheet(
        dayLabel: dayLabel,
        classOptions: classOptions,
        initial: _schedule
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList(),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _scheduleLoading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/teacher/dashboard/schedule',
            data: {
              'day': _selectedDay,
              'slots': result['reset'] == true ? <dynamic>[] : result['slots'],
            },
          );
      if (!mounted) return;
      setState(() {
        _schedule = res.data as List<dynamic>? ?? [];
        if (_selectedDay == _todayIndex) _todaySchedule = _schedule;
        _scheduleLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['reset'] == true
                ? 'Timetable reset to default'
                : 'Timetable saved',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.teacherPrimary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _scheduleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save timetable. Try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToTab(int index) {
    ref.read(teacherShellTabProvider.notifier).state = index;
  }

  String _greetingName(String? fullName) {
    final name = fullName?.trim() ?? 'Teacher';
    return name;
  }

  String _shortDate(String today) {
    // "Sunday, 14 Jun 2026" -> "14 Jun 2026" for compact header
    final parts = today.split(', ');
    return parts.length > 1 ? parts.sublist(1).join(', ') : today;
  }

  String _subjectLabel(Map<String, dynamic>? teacher) {
    final subjects = teacher?['subjects'] as List?;
    if (subjects != null && subjects.isNotEmpty) {
      return '${subjects.first} Teacher';
    }
    final dept = teacher?['department'];
    if (dept != null && '$dept'.isNotEmpty) return '$dept Teacher';
    return 'Subject Teacher';
  }

  String _formatClock(dynamic raw) {
    final s = '$raw'.trim();
    if (s.contains('AM') || s.contains('PM')) return s;
    final parts = s.split(':');
    if (parts.length < 2) return s;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final dt = DateTime(2024, 1, 1, h, m);
    return DateFormat('hh:mm a').format(dt);
  }

  /// Minutes since midnight for a "08:00 AM" / "14:30" style label.
  int? _clockMinutes(dynamic raw) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch('$raw'.trim());
    if (match == null) return null;
    var h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final ap = match.group(3)?.toUpperCase();
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return h * 60 + m;
  }

  /// How many of today's periods have already finished.
  int _completedCount(List<dynamic> periods) {
    final now = DateTime.now();
    final nowM = now.hour * 60 + now.minute;
    var done = 0;
    for (final p in periods) {
      if ((p as Map)['current'] == true) continue;
      final end = _clockMinutes(p['end']);
      if (end != null && end <= nowM) done++;
    }
    return done;
  }

  void _scrollToTimetable() {
    final ctx = _timetableKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  /// Open the attendance sheet. One class goes straight there; several show a
  /// short picker first so marking is never more than two taps away.
  Future<void> _openAttendance() async {
    if (_classes.isEmpty) {
      _comingSoon('No classes assigned yet');
      return;
    }

    Map<String, dynamic>? target;
    if (_classes.length == 1) {
      target = Map<String, dynamic>.from(_classes.first as Map);
    } else {
      target = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mark attendance for',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
              for (final raw in _classes)
                ListTile(
                  leading: const Icon(
                    Icons.school_rounded,
                    color: AppColors.teacherPrimary,
                  ),
                  title: Text(
                    '${(raw as Map)['name'] ?? '${raw['grade']}${raw['section']}'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${raw['_count']?['students'] ?? 0} students',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () =>
                      Navigator.of(ctx).pop(Map<String, dynamic>.from(raw)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    if (target == null || !mounted) return;
    openSmoothPage(
      context,
      TeacherAttendanceScreen(
        classId: '${target['id']}',
        classLabel:
            '${target['name'] ?? '${target['grade']}${target['section']}'}',
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final teacher = _data?['teacher'] as Map<String, dynamic>?;
    final displayName = teacher?['fullName'] ?? user?.fullName ?? 'Teacher';
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());

    return ColoredBox(
      color: _dashBg,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teacherPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, displayName)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_hPad, 14, _hPad, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildScheduleHero(),
                  const SizedBox(height: 24),
                  const _SectionTitle('Overview'),
                  const SizedBox(height: 12),
                  _buildOverviewGrid(),
                  const SizedBox(height: 24),
                  const _SectionTitle('Quick Access'),
                  const SizedBox(height: 12),
                  _buildQuickAccess(),
                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: _timetableKey,
                    child: _buildTimetable(today),
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    'My Classes',
                    trailing: GestureDetector(
                      onTap: () => _goToTab(2),
                      child: const Text(
                        'View All Students >',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teacherPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._classes.take(4).map(_classRow),
                  if (_classes.isEmpty && !_loading)
                    _emptyCard('No classes assigned yet.'),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    'Upcoming Assignments',
                    trailing: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teacherPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHomeworkRow(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    final top = MediaQuery.paddingOf(context).top;
    final unread = ref.watch(unreadNotificationCountProvider);

    final role = _subjectLabel(_data?['teacher'] as Map<String, dynamic>?);

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 8, _hPad, 4),
      child: Row(
        children: [
          // Same side-panel control the other teacher tabs get from
          // TeacherPlainHeader. Builder supplies a context below the Scaffold
          // so Scaffold.of can reach the shell's drawer.
          Builder(
            builder: (context) => Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Scaffold.of(context).openDrawer(),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  height: 42,
                  width: 42,
                  child: Icon(
                    Icons.segment_rounded,
                    color: _headerPurple,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${teacherGreeting()} 👋',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _headerPurple.withValues(alpha: 0.5),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _greetingName(displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _headerPurple,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        size: 11,
                        color: AppColors.teacherPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teacherPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _notificationBell(context, unread),
        ],
      ),
    );
  }

  Widget _notificationBell(BuildContext context, int unread) {
    return GestureDetector(
      onTap: () => openSmoothPage(context, const TeacherAnnouncementsScreen()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _headerPurple,
              size: 22,
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // "Today's Schedule" hero — compact card (tap to jump to timetable)
  // ---------------------------------------------------------------------
  Widget _buildScheduleHero() {
    final isSunday = _todayIndex == 0;
    final periods = isSunday ? const <dynamic>[] : _todaySchedule;
    final count = periods.length;
    final done = _completedCount(periods);
    final dateLabel = DateFormat('EEE, d MMM').format(DateTime.now());
    final pct = count == 0 ? 0.0 : (done / count).clamp(0.0, 1.0);

    final remaining = count - done;
    final String statusLine;
    if (count == 0) {
      statusLine = isSunday ? 'Day off — enjoy!' : 'No classes today';
    } else if (remaining <= 0) {
      statusLine = 'All classes done 🎉';
    } else {
      statusLine =
          '$remaining ${remaining == 1 ? 'class' : 'classes'} left today';
    }

    return GestureDetector(
      onTap: _scrollToTimetable,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          "Today's Schedule",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loading ? 'Loading…' : statusLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!_loading && count > 0) ...[
              const SizedBox(width: 12),
              _heroProgressRing(done, count, pct),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroProgressRing(int done, int total, double pct) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: pct == 0 ? 0.001 : pct,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          Text(
            '$done/$total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Overview — 2×2 stat cards
  // ---------------------------------------------------------------------
  Widget _buildOverviewGrid() {
    final students = '${_data?['totalStudents'] ?? 0}';
    final attendance = '${_data?['attendanceMarkedPercent'] ?? 0}%';
    final classes = '${_data?['classCount'] ?? _classes.length}';
    final tasks = '${_data?['tasksCount'] ?? _data?['pendingGrading'] ?? 0}';

    return Row(
      children: [
        _statCard(
          icon: Icons.groups_rounded,
          color: AppColors.teacherPrimary,
          label: 'Students',
          value: students,
          onTap: () => _goToTab(2),
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.fact_check_rounded,
          color: AppColors.statGreen,
          label: 'Attendance',
          value: attendance,
          onTap: () => _goToTab(2),
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF3B82F6),
          label: 'Classes',
          value: classes,
          onTap: () => openSmoothPage(context, const TeacherClassesScreen()),
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.task_alt_rounded,
          color: AppColors.statOrange,
          label: 'Tasks',
          value: tasks,
          onTap: () => _goToTab(3),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: _premiumCard(),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _headerPurple,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Weekly timetable — day selector chips + vertical period timeline
  // ---------------------------------------------------------------------
  static const _dayChips = <({int day, String label})>[
    (day: 1, label: 'Mon'),
    (day: 2, label: 'Tue'),
    (day: 3, label: 'Wed'),
    (day: 4, label: 'Thu'),
    (day: 5, label: 'Fri'),
    (day: 6, label: 'Sat'),
  ];

  static const _periodColors = [
    AppColors.teacherPrimary,
    AppColors.statGreen,
    AppColors.statOrange,
    Color(0xFF3B82F6),
    AppColors.statPink,
    Color(0xFF0D9488),
  ];

  Widget _buildTimetable(String today) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: _premiumCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.teacherPrimary,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Timetable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _headerPurple,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                _shortDate(today),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _scheduleLoading ? null : _openTimetableEditor,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [teacherHeaderStart, teacherHeaderEnd],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teacherPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final chip in _dayChips) ...[
                Expanded(child: _dayChip(chip.day, chip.label)),
                if (chip.day != 6) const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 2),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _buildTimetableBody(),
          ),
        ],
      ),
    );
  }

  Widget _dayChip(int day, String label) {
    final selected = day == _selectedDay;
    final isToday = day == _todayIndex;

    return GestureDetector(
      onTap: () => _selectDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.teacherPrimary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? (selected ? Colors.white : AppColors.teacherPrimary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableBody() {
    if (_loading || _scheduleLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              color: AppColors.teacherPrimary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    if (_schedule.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 30,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              const Text(
                'No classes on this day',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    const collapsedCount = 3;
    final visible = _showAllPeriods
        ? _schedule.length
        : (_schedule.length > collapsedCount
              ? collapsedCount
              : _schedule.length);
    final hiddenCount = _schedule.length - visible;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (var i = 0; i < visible; i++)
            _periodRow(
              _schedule[i] as Map<String, dynamic>,
              i,
              isLast: i == visible - 1 && hiddenCount == 0,
            ),
          if (hiddenCount > 0 || _showAllPeriods)
            GestureDetector(
              onTap: () => setState(() => _showAllPeriods = !_showAllPeriods),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showAllPeriods
                          ? 'Show less'
                          : 'Show all ${_schedule.length} periods',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teacherPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      _showAllPeriods
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: AppColors.teacherPrimary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _periodRow(Map<String, dynamic> p, int index, {required bool isLast}) {
    final current = p['current'] == true;
    final color = _periodColors[index % _periodColors.length];
    final subject = '${p['subject'] ?? 'Class'}';
    final classLabel = '${p['classLabel'] ?? ''}';
    final room = '${p['location'] ?? p['room'] ?? '—'}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0F1F6))),
      ),
      child: Row(
        children: [
          // Time column
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatClock(p['start']),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: current ? AppColors.teacherPrimary : _headerPurple,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _formatClock(p['end']),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _headerPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$classLabel · $room',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (current)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess() {
    final tiles =
        <({IconData icon, String label, Color color, VoidCallback onTap})>[
          (
            icon: Icons.school_rounded,
            label: 'My Classes',
            color: AppColors.teacherPrimary,
            onTap: () => openSmoothPage(context, const TeacherClassesScreen()),
          ),
          (
            icon: Icons.fact_check_rounded,
            label: 'Attendance',
            color: AppColors.statGreen,
            onTap: _openAttendance,
          ),
          (
            icon: Icons.menu_book_rounded,
            label: 'Homework',
            color: AppColors.statPink,
            onTap: () => _comingSoon('Homework'),
          ),
          (
            icon: Icons.description_rounded,
            label: 'Reports',
            color: const Color(0xFF3B82F6),
            onTap: () => _goToTab(3),
          ),
        ];

    Widget tile(
      ({IconData icon, String label, Color color, VoidCallback onTap}) t,
    ) {
      return Expanded(
        child: GestureDetector(
          onTap: t.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFEDEFF5)),
                  boxShadow: [
                    BoxShadow(
                      color: t.color.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(t.icon, color: t.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                t.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: _premiumCard(),
      child: Row(children: [for (final t in tiles) tile(t)]),
    );
  }

  Widget _classRow(dynamic raw) {
    final c = raw as Map<String, dynamic>;
    final colors = [
      AppColors.teacherPrimary,
      AppColors.statGreen,
      AppColors.statOrange,
      AppColors.statPink,
    ];
    final idx = (_classes.indexOf(raw)) % colors.length;
    final color = colors[idx];
    final gradeSection = '${c['grade']}${c['section']}';
    final count = c['_count']?['students'] ?? 0;
    final subject = (c['category'] ?? 'Class').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: _premiumCard(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              gradeSection,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class $gradeSection',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _headerPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count Students',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkRow() {
    if (_homework.isEmpty) {
      return _emptyCard('No upcoming assignments.');
    }

    final colors = [
      AppColors.teacherPrimary,
      AppColors.statGreen,
      AppColors.statOrange,
      AppColors.statPink,
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _homework.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final h = _homework[i] as Map<String, dynamic>;
          final cls = h['class'] as Map<String, dynamic>?;
          final gradeSection = cls != null
              ? '${cls['grade']}${cls['section']}'
              : '';
          final subject = cls?['category'] ?? 'Subject';
          final due = DateTime.tryParse('${h['dueDate']}');
          final dueLabel = due != null
              ? DateFormat('d MMM yyyy').format(due)
              : '—';
          final color = colors[i % colors.length];

          return Container(
            width: 224,
            padding: const EdgeInsets.all(14),
            decoration: _premiumCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${h['title'] ?? 'Assignment'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: _headerPurple,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Class $gradeSection • $subject',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: $dueLabel',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _premiumCard(),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _headerPurple,
              letterSpacing: -0.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timetable editor bottom sheet
// ---------------------------------------------------------------------------
class _EditSlot {
  _EditSlot({
    required this.start,
    required this.end,
    required String subject,
    required String room,
    this.classLabel,
  }) : subjectCtrl = TextEditingController(text: subject),
       roomCtrl = TextEditingController(text: room);

  String start;
  String end;
  final TextEditingController subjectCtrl;
  final TextEditingController roomCtrl;
  String? classLabel;

  void dispose() {
    subjectCtrl.dispose();
    roomCtrl.dispose();
  }
}

class _TimetableEditorSheet extends StatefulWidget {
  const _TimetableEditorSheet({
    required this.dayLabel,
    required this.classOptions,
    required this.initial,
  });

  final String dayLabel;
  final List<String> classOptions;
  final List<Map<String, dynamic>> initial;

  @override
  State<_TimetableEditorSheet> createState() => _TimetableEditorSheetState();
}

class _TimetableEditorSheetState extends State<_TimetableEditorSheet> {
  late final List<_EditSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = widget.initial
        .map(
          (p) => _EditSlot(
            start: '${p['start'] ?? '08:00 AM'}',
            end: '${p['end'] ?? '08:45 AM'}',
            subject: '${p['subject'] ?? ''}',
            room: '${p['location'] ?? p['room'] ?? ''}',
            classLabel: widget.classOptions.contains('${p['classLabel']}')
                ? '${p['classLabel']}'
                : null,
          ),
        )
        .toList();
    if (_slots.isEmpty) _addSlot();
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSlot() {
    final last = _slots.isNotEmpty ? _slots.last : null;
    setState(() {
      _slots.add(
        _EditSlot(
          start: last != null ? _shiftHour(last.start) : '08:00 AM',
          end: last != null ? _shiftHour(last.end) : '08:45 AM',
          subject: '',
          room: last?.roomCtrl.text ?? '',
          classLabel: widget.classOptions.isNotEmpty
              ? widget.classOptions.first
              : null,
        ),
      );
    });
  }

  static String _shiftHour(String label) {
    final t = _parseTime(label);
    if (t == null) return label;
    final dt = DateTime(
      2024,
      1,
      1,
      t.hour,
      t.minute,
    ).add(const Duration(hours: 1));
    return DateFormat('hh:mm a').format(dt);
  }

  static TimeOfDay? _parseTime(String label) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(label.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final pm = match.group(3)!.toUpperCase() == 'PM';
    hour = (hour % 12) + (pm ? 12 : 0);
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime(_EditSlot slot, {required bool isStart}) async {
    final current =
        _parseTime(isStart ? slot.start : slot.end) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.teacherPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final label = DateFormat(
      'hh:mm a',
    ).format(DateTime(2024, 1, 1, picked.hour, picked.minute));
    setState(() {
      if (isStart) {
        slot.start = label;
      } else {
        slot.end = label;
      }
    });
  }

  void _save() {
    final slots = _slots
        .map(
          (s) => {
            'start': s.start,
            'end': s.end,
            'subject': s.subjectCtrl.text.trim().isEmpty
                ? 'Class'
                : s.subjectCtrl.text.trim(),
            'classLabel': s.classLabel ?? '',
            'room': s.roomCtrl.text.trim(),
          },
        )
        .toList();
    Navigator.of(context).pop({'slots': slots});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [teacherHeaderStart, teacherHeaderEnd],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.edit_calendar_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Timetable · ${widget.dayLabel}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _headerPurple,
                        ),
                      ),
                      const Text(
                        'Tap times to change · swipe fields to edit',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              itemCount: _slots.length,
              separatorBuilder: (_, i) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _slotEditor(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Period'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teacherPrimary,
                      side: BorderSide(
                        color: AppColors.teacherPrimary.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [teacherHeaderStart, teacherHeaderEnd],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        onTap: _save,
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                            child: Text(
                              'Save Timetable',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop({'reset': true}),
              child: const Text(
                'Reset this day to default',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotEditor(int index) {
    final slot = _slots[index];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teacherPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.teacherPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _timeChip(slot.start, () => _pickTime(slot, isStart: true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('–', style: TextStyle(color: AppColors.textMuted)),
              ),
              _timeChip(slot.end, () => _pickTime(slot, isStart: false)),
              const Spacer(),
              GestureDetector(
                onTap: _slots.length <= 1
                    ? null
                    : () => setState(() {
                        _slots.removeAt(index).dispose();
                      }),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: _slots.length <= 1
                      ? Colors.grey.shade300
                      : Colors.red.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _editorField(
                  controller: slot.subjectCtrl,
                  hint: 'Subject',
                  icon: Icons.menu_book_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _editorField(
                  controller: slot.roomCtrl,
                  hint: 'Room',
                  icon: Icons.location_on_outlined,
                ),
              ),
            ],
          ),
          if (widget.classOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: slot.classLabel,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text(
                    'Select class',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _headerPurple,
                  ),
                  items: widget.classOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => slot.classLabel = v),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: AppColors.teacherPrimary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 12,
              color: AppColors.teacherPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _headerPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 15, color: AppColors.teacherPrimary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.teacherPrimary),
        ),
      ),
    );
  }
}
