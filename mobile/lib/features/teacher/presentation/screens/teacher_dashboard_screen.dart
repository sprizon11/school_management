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
