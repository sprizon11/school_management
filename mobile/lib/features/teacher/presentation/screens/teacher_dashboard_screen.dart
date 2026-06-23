import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/teacher_shell_provider.dart';
import '../widgets/teacher_ui.dart';

const _dashBg = Color(0xFFF8F9FE);
const _headerPurple = Color(0xFF1E1B4B);
const _hPad = 16.0;
const _scheduleCardW = 108.0;
const _scheduleCardH = 88.0;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final summary = await dio.get('/teacher/dashboard/summary');
      final schedule = await dio.get('/teacher/dashboard/schedule');
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

  String _scheduleTimeLabel(Map<String, dynamic> p) {
    final existing = p['timeLabel']?.toString();
    if (existing != null && existing.contains('AM')) return existing;
    return '${_formatClock(p['start'])} - ${_formatClock(p['end'])}';
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

  String _scheduleClassLabel(Map<String, dynamic> p, int index) {
    final label = p['classLabel']?.toString();
    if (label != null && label != 'Class' && label.length > 5) return label;
    if (_classes.isNotEmpty) {
      final c = _classes[index % _classes.length] as Map<String, dynamic>;
      return 'Class ${c['grade']}${c['section']}';
    }
    return label ?? 'Class';
  }

  String _scheduleLocation(Map<String, dynamic> p, int index) {
    final loc = p['location']?.toString();
    if (loc != null && loc.isNotEmpty && loc != '—') return loc;
    final room = p['room']?.toString();
    if (room != null && room.isNotEmpty) {
      return room.toLowerCase().contains('room') || room.toLowerCase().contains('lab')
          ? room
          : 'Room $room';
    }
    if (_classes.isNotEmpty) {
      final c = _classes[index % _classes.length] as Map<String, dynamic>;
      final r = c['room'];
      if (r != null && '$r'.isNotEmpty) return 'Room $r';
    }
    return '—';
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
              padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildProfileAndStats(displayName, teacher),
                  const SizedBox(height: 18),
                  _buildScheduleHeader(today),
                  const SizedBox(height: 8),
                  _buildScheduleRow(),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 4, _hPad, 0),
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
          const SizedBox(height: 14),
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

  Widget _buildScheduleHeader(String today) {
    final shortDate = _shortDate(today);
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.teacherPrimary),
        const SizedBox(width: 6),
        const Text(
          "Today's Schedule",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _headerPurple,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            shortDate,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ),
        _purplePillButton('View Timetable', () {}),
      ],
    );
  }

  Widget _purplePillButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.teacherPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleRow() {
    if (_loading) {
      return const SizedBox(
        height: _scheduleCardH,
        child: Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary, strokeWidth: 2)),
      );
    }
    if (_schedule.isEmpty) {
      return _emptyCard('No schedule for today.');
    }

    return SizedBox(
      height: _scheduleCardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _schedule.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = _schedule[i] as Map<String, dynamic>;
          final current = p['current'] == true;
          return Container(
            width: _scheduleCardW,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            decoration: BoxDecoration(
              color: current ? const Color(0xFFF5F3FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: current ? AppColors.teacherPrimary.withValues(alpha: 0.45) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scheduleTimeLabel(p),
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: current ? AppColors.teacherPrimary : AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _scheduleClassLabel(p, i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _headerPurple,
                        height: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _scheduleLocation(p, i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted, height: 1.1),
                    ),
                  ],
                ),
                if (current)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.menu_book_rounded, size: 14, color: AppColors.teacherPrimary),
                  ),
              ],
            ),
          );
        },
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

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: actions.length,
        separatorBuilder: (_, index) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final (icon, label, color) = actions[i];
          return SizedBox(
            width: 64,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '85%',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.statGreen),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
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
