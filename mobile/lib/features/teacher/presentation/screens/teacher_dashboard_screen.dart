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
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  Map<String, dynamic>? _data;
  List<dynamic> _schedule = [];
  List<dynamic> _classes = [];
  List<dynamic> _homework = [];
  bool _loading = true;
  bool _scheduleLoading = false;

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
    });
    try {
      final res = await ref.read(dioProvider).get(
        '/teacher/dashboard/schedule',
        queryParameters: {'day': day},
      );
      if (!mounted || _selectedDay != day) return;
      setState(() {
        _schedule = res.data as List<dynamic>? ?? [];
        _scheduleLoading = false;
      });
    } catch (_) {
      if (mounted && _selectedDay == day) {
        setState(() => _scheduleLoading = false);
      }
    }
  }

  Future<void> _openTimetableEditor() async {
    final dayLabel =
        _dayChips.firstWhere((c) => c.day == _selectedDay).label;
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
      final res = await ref.read(dioProvider).post(
        '/teacher/dashboard/schedule',
        data: {
          'day': _selectedDay,
          'slots': result['reset'] == true ? <dynamic>[] : result['slots'],
        },
      );
      if (!mounted) return;
      setState(() {
        _schedule = res.data as List<dynamic>? ?? [];
        _scheduleLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['reset'] == true
              ? 'Timetable reset to default'
              : 'Timetable saved'),
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
                  _buildProfileAndStats(displayName, teacher),
                  const SizedBox(height: 18),
                  _buildTimetable(today),
                  const SizedBox(height: 22),
                  const _SectionTitle('Quick Actions'),
                  const SizedBox(height: 14),
                  _buildQuickActions(),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 4, _hPad, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${teacherGreeting()},',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _headerPurple.withValues(alpha: 0.55),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_greetingName(displayName)} 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _headerPurple,
                    height: 1.1,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Here's what's happening in your classes today.",
                  style: TextStyle(
                    fontSize: 12,
                    color: _headerPurple.withValues(alpha: 0.45),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
              top: 2,
              right: 2,
              child: Container(
                height: 11,
                width: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAndStats(String displayName, Map<String, dynamic>? teacher) {
    final employeeCode = teacher?['employeeCode'];
    final employeeLine = employeeCode != null && '$employeeCode'.isNotEmpty && '$employeeCode' != '—'
        ? employeeCode.toString()
        : null;
    final subjectLine = _subjectLabel(teacher);
    final classCount = '${_data?['classCount'] ?? _classes.length}';
    final students = '${_data?['totalStudents'] ?? 0}';
    final attendance = '${_data?['attendanceMarkedPercent'] ?? 0}%';
    final tasks = '${_data?['tasksCount'] ?? _data?['pendingGrading'] ?? 0}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5DF6), Color(0xFF5146E5), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5146E5).withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF5146E5).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -16,
            bottom: 20,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subjectLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (employeeLine != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                'ID · $employeeLine',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      _gradientStatTile(classCount, 'Classes', Icons.menu_book_rounded),
                      _gradientStatDivider(),
                      _gradientStatTile(students, 'Students', Icons.groups_rounded),
                      _gradientStatDivider(),
                      _gradientStatTile(attendance, 'Attendance', Icons.fact_check_outlined),
                      _gradientStatDivider(),
                      _gradientStatTile(tasks, 'Tasks', Icons.task_alt_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientStatDivider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.18),
      );

  Widget _gradientStatTile(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
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
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
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
          const SizedBox(height: 12),
          Row(
            children: [
              for (final chip in _dayChips) ...[
                Expanded(child: _dayChip(chip.day, chip.label)),
                if (chip.day != 6) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(11),
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
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
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
              Icon(Icons.event_busy_rounded,
                  size: 30, color: Colors.grey.shade300),
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

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (var i = 0; i < _schedule.length; i++)
            _periodRow(
              _schedule[i] as Map<String, dynamic>,
              i,
              isLast: i == _schedule.length - 1,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatClock(p['start']),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: current ? AppColors.teacherPrimary : _headerPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatClock(p['end']),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Timeline rail
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current ? color : Colors.white,
                    border: Border.all(color: color, width: 2.5),
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Period card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 2 : 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: current
                    ? const Color(0xFFF5F3FF)
                    : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: current
                      ? AppColors.teacherPrimary.withValues(alpha: 0.4)
                      : const Color(0xFFEDEFF5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
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
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.how_to_reg_rounded, 'Attendance', AppColors.teacherPrimary),
      (Icons.grade_rounded, 'Marks', AppColors.statGreen),
      (Icons.assignment_outlined, 'Assignment', AppColors.statOrange),
      (Icons.campaign_outlined, 'Announce', const Color(0xFF3B82F6)),
      (Icons.bar_chart_rounded, 'Reports', AppColors.statPink),
      (Icons.more_horiz_rounded, 'More', AppColors.teacherPrimary),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _premiumCard(),
      child: SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: actions.length,
          separatorBuilder: (_, index) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final (icon, label, color) = actions[i];
            return SizedBox(
              width: 62,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.15)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
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
                Text(subject, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '$count Students',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: Color(0xFF9CA3AF)),
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
          final gradeSection = cls != null ? '${cls['grade']}${cls['section']}' : '';
          final subject = cls?['category'] ?? 'Subject';
          final due = DateTime.tryParse('${h['dueDate']}');
          final dueLabel = due != null ? DateFormat('d MMM yyyy').format(due) : '—';
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
                      child: Icon(Icons.assignment_rounded, size: 16, color: color),
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
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Due: $dueLabel',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
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
      child: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
  })  : subjectCtrl = TextEditingController(text: subject),
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
          classLabel:
              widget.classOptions.isNotEmpty ? widget.classOptions.first : null,
        ),
      );
    });
  }

  static String _shiftHour(String label) {
    final t = _parseTime(label);
    if (t == null) return label;
    final dt = DateTime(2024, 1, 1, t.hour, t.minute)
        .add(const Duration(hours: 1));
    return DateFormat('hh:mm a').format(dt);
  }

  static TimeOfDay? _parseTime(String label) {
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
            .firstMatch(label.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final pm = match.group(3)!.toUpperCase() == 'PM';
    hour = (hour % 12) + (pm ? 12 : 0);
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime(_EditSlot slot, {required bool isStart}) async {
    final current = _parseTime(isStart ? slot.start : slot.end) ??
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
    final label = DateFormat('hh:mm a')
        .format(DateTime(2024, 1, 1, picked.hour, picked.minute));
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
                  child: const Icon(Icons.edit_calendar_rounded,
                      size: 17, color: Colors.white),
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
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
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
                        color:
                            AppColors.teacherPrimary.withValues(alpha: 0.4),
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
              onPressed: () =>
                  Navigator.of(context).pop({'reset': true}),
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
                child: Text('–',
                    style: TextStyle(color: AppColors.textMuted)),
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
                  hint: const Text('Select class',
                      style: TextStyle(fontSize: 12.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _headerPurple,
                  ),
                  items: widget.classOptions
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      )
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
            const Icon(Icons.schedule_rounded,
                size: 12, color: AppColors.teacherPrimary),
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
        hintStyle:
            TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 15, color: AppColors.teacherPrimary),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
