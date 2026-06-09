import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_add_class_screen.dart';
import 'admin_add_student_flow_screen.dart';
import 'admin_add_teacher_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_examinations_screen.dart';
import 'admin_fee_collection_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_timetable_screen.dart';
import 'admin_profile_screen.dart';
import '../widgets/admin_sidebar.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, this.onTabSelect});

  final ValueChanged<int>? onTabSelect;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const _hPad = 16.0;
  static const _cardRadius = 20.0;
  static const _statsCardHeight = 112.0;

  Map<String, dynamic>? _summary;
  List<dynamic>? _chartPoints;
  Map<String, dynamic>? _feeChart;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openSidebar() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Map<String, dynamic> _emptySummary() => {
        'students': {'count': 0, 'boys': 0, 'girls': 0},
        'teachers': {'count': 0, 'male': 0, 'female': 0},
        'classes': {'count': 0, 'students': 0},
        'feeCollection': {'amount': 0, 'total': 0},
        'attendancePercent': 0,
        'announcements': <dynamic>[],
        'activities': <dynamic>[],
      };

  Map<String, dynamic> _emptyFeeChart() => {
        'total': 0,
        'segments': <dynamic>[],
      };

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    Map<String, dynamic>? summary;
    List<dynamic>? chartPoints;
    Map<String, dynamic>? feeChart;

    try {
      final res = await dio.get('/admin/dashboard/summary');
      summary = res.data as Map<String, dynamic>;
    } catch (_) {
      summary = _emptySummary();
    }

    try {
      final res = await dio.get('/admin/dashboard/attendance-chart');
      chartPoints = (res.data as Map)['points'] as List<dynamic>? ?? [];
    } catch (_) {
      chartPoints = [];
    }

    try {
      final res = await dio.get('/admin/dashboard/fee-chart');
      feeChart = res.data as Map<String, dynamic>;
    } catch (_) {
      feeChart = _emptyFeeChart();
    }

    if (!mounted) return;
    setState(() {
      _summary = summary ?? _emptySummary();
      _chartPoints = chartPoints ?? [];
      _feeChart = feeChart ?? _emptyFeeChart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullName = ref.watch(
      authProvider.select((a) => a.user?.fullName ?? 'Admin'),
    );
    final schoolName = ref.watch(authProvider.select((a) => a.user?.schoolName));
    final selectedSchool = ref.watch(selectedSchoolProvider);
    final displaySchool = (schoolName != null && schoolName.isNotEmpty)
        ? schoolName
        : (selectedSchool?.name ?? 'Your School');
    final hasSummary = _summary != null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F6FB),
      drawer: AdminSidebar(onTabSelect: widget.onTabSelect),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _headerSection(displaySchool, fullName),
            _sectionTitle('Quick Access'),
            const SizedBox(height: 12),
            _quickAccessGrid(),
            const SizedBox(height: 20),
            if (hasSummary)
              FadeInContent(child: _overviewSection())
            else
              _overviewSkeleton(),
            const SizedBox(height: 20),
            if (hasSummary)
              FadeInContent(child: _announcementsSection())
            else
              _announcementsSkeleton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _overviewSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Overview', trailing: 'More'),
          const SizedBox(height: 12),
          const SkeletonBox(height: 200, borderRadius: 20),
          const SizedBox(height: 14),
          const SkeletonBox(height: 220, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _announcementsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Recent Announcements', trailing: 'View All'),
          const SizedBox(height: 12),
          const SkeletonBox(height: 120, borderRadius: 20),
        ],
      ),
    );
  }

  Widget _headerSection(String schoolName, String fullName) {
    const statsOverhang = 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _blueHeader(schoolName, fullName, statsInset: statsOverhang),
            Positioned(
              left: _hPad,
              right: _hPad,
              bottom: -statsOverhang,
              child: _statsStrip(),
            ),
          ],
        ),
        const SizedBox(height: statsOverhang + 14),
      ],
    );
  }

  Widget _blueHeader(String schoolName, String fullName, {double statsInset = 0}) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        _hPad,
        topPad + 10,
        _hPad,
        20 + statsInset,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0835B8), Color(0xFF1B5FFF), Color(0xFF3D7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: 0,
            child: Icon(
              Icons.apartment_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _openSidebar,
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _profileAvatar(fullName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileAvatar(String fullName) {
    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: () => openSmoothPage(context, const AdminProfileScreen()),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: Text(
            initials.isEmpty ? 'A' : initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsStrip() {
    if (_summary == null) {
      return const SkeletonBox(height: _statsCardHeight, borderRadius: 18);
    }

    final stats = [
      (
        label: 'Classes',
        value: _formatNumber(_summary?['classes']?['count']),
        detail: '${_formatNumber(_summary?['classes']?['students'])} enrolled',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFF5A623),
        onTap: () => widget.onTabSelect?.call(3),
      ),
      (
        label: 'Students',
        value: _formatNumber(_summary?['students']?['count']),
        detail:
            'Boys ${_formatNumber(_summary?['students']?['boys'])} · Girls ${_formatNumber(_summary?['students']?['girls'])}',
        icon: Icons.groups_rounded,
        color: const Color(0xFF4F6FFF),
        onTap: () => widget.onTabSelect?.call(1),
      ),
      (
        label: 'Teachers',
        value: _formatNumber(_summary?['teachers']?['count']),
        detail:
            'Gents ${_formatNumber(_summary?['teachers']?['male'])} · Ladies ${_formatNumber(_summary?['teachers']?['female'])}',
        icon: Icons.school_rounded,
        color: const Color(0xFF3CCB6F),
        onTap: () => widget.onTabSelect?.call(2),
      ),
    ];

    return Container(
      height: _statsCardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 56,
                  color: const Color(0xFFEEF1F6),
                ),
              Expanded(
                child: _statColumn(stats[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statColumn(
    ({
      String label,
      String value,
      String detail,
      IconData icon,
      Color color,
      VoidCallback? onTap,
    }) stat,
  ) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: stat.onTap,
        splashColor: stat.color.withValues(alpha: 0.08),
        highlightColor: stat.color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [stat.color, stat.color.withValues(alpha: 0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(stat.icon, color: Colors.white, size: 15),
              ),
              const SizedBox(height: 5),
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat.value,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Color(0xFF131B2E),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickAccessGrid() {
    final items = [
      ('Student', Icons.person_add_alt_1_rounded, const Color(0xFF5B6CFF), () => const AdminAddStudentFlowScreen()),
      ('Teacher', Icons.manage_accounts_rounded, const Color(0xFF3DD16E), () => const AdminAddTeacherScreen()),
      ('Class', Icons.menu_book_rounded, const Color(0xFFF5A623), () => const AdminAddClassScreen()),
      ('Attendance', Icons.fact_check_rounded, const Color(0xFF2F8DFF), () => const AdminAttendanceScreen()),
      ('Fees', Icons.currency_rupee_rounded, const Color(0xFF34B356), () => const AdminFeeCollectionScreen()),
      ('Exams', Icons.edit_note_rounded, const Color(0xFF6B5CE7), () => const AdminExaminationsScreen()),
      ('Schedule', Icons.calendar_month_rounded, const Color(0xFF3B9EFF), () => const AdminTimetableScreen()),
      ('Reports', Icons.bar_chart_rounded, const Color(0xFFFF5D6E), () => const AdminReportsScreen()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (_, i) {
          final item = items[i];
          return _quickAccessCard(
            label: item.$1,
            icon: item.$2,
            color: item.$3,
            onTap: () => openSmoothPage(context, item.$4()),
          );
        },
      ),
    );
  }

  Widget _quickAccessCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF5)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Icon(
                    icon,
                    size: 40,
                    color: color.withValues(alpha: 0.06),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.72)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.28),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 18),
                          ),
                          Positioned(
                            right: -5,
                            bottom: -5,
                            child: Container(
                              height: 17,
                              width: 17,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overviewSection() {
    return Column(
      children: [
        _sectionTitle('Overview', trailing: 'More'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          child: Column(
            children: [
              _attendanceCard(),
              const SizedBox(height: 14),
              _feeCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attendanceCard() {
    final points = _chartPoints ?? [];
    final avg = _toInt(_summary?['attendancePercent']);
    final maxX = points.isEmpty ? 6.0 : (points.length - 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _overviewCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Attendance Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              _capsule('This Week'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$avg%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Average Attendance',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFEEF1F6),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${points[i]['day'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      points.length,
                      (i) => FlSpot(
                        i.toDouble(),
                        (points[i]['percent'] as num).toDouble(),
                      ),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.22),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _feeCard() {
    final segments = (_feeChart?['segments'] as List<dynamic>? ?? []);
    final total = _toInt(_feeChart?['total']);
    final colors = <Color>[
      const Color(0xFF3BC75A),
      const Color(0xFFF8C22A),
      const Color(0xFFFF5D5D),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _overviewCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fee Collection Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              _capsule('This Month'),
            ],
          ),
          const SizedBox(height: 16),
          RepaintBoundary(
            child: SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 42,
                    startDegreeOffset: -90,
                    sections: List.generate(segments.length, (i) {
                      final seg = segments[i] as Map<String, dynamic>;
                      return PieChartSectionData(
                        value: (seg['percent'] as num?)?.toDouble() ?? 0,
                        color: colors[i % colors.length],
                        radius: 36,
                        showTitle: false,
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 12),
          ...List.generate(segments.length, (i) {
            final seg = segments[i] as Map<String, dynamic>;
            final label = '${seg['label']}';
            final amount = _formatCurrency(seg['amount']);
            final percent = _toInt(seg['percent']);
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _announcementsSection() {
    final items = (_summary?['announcements'] as List<dynamic>? ?? []);
    return Column(
      children: [
        _sectionTitle('Recent Announcements', trailing: 'View All'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF20345B).withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No announcements yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : Column(
                    children: List.generate(
                      items.length > 2 ? 2 : items.length,
                      (i) {
                        final item = items[i] as Map<String, dynamic>;
                        final isLast = i == (items.length > 2 ? 1 : items.length - 1);
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 42,
                                    width: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F8EE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.campaign_rounded,
                                      color: Color(0xFF22A750),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['title'] ?? 'School Notice'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${item['content'] ?? ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '1 day ago',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 14,
                                color: Color(0xFFEEF1F6),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _overviewCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(color: const Color(0xFFE8EDF5)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF20345B).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _capsule(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    final n = _toInt(value);
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final pos = s.length - i - 1;
      if (pos > 0 && pos % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  String _formatCurrency(dynamic value) {
    return '₹${_formatNumber(value)}';
  }

  String _formatCompactCurrency(dynamic value) {
    final n = _toInt(value);
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹$n';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
