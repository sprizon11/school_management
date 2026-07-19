import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_attendance_screen.dart';
import 'admin_examinations_screen.dart';
import 'admin_fee_collection_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_announcements_screen.dart';
import '../widgets/admin_screen_header.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, this.onTabSelect});

  final ValueChanged<int>? onTabSelect;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const _hPad = 16.0;
  static const _ink = Color(0xFF1A1533);

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _feeChart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openSidebar() => Scaffold.of(context).openDrawer();

  Map<String, dynamic> _emptySummary() => {
    'students': {'count': 0, 'boys': 0, 'girls': 0},
    'teachers': {'count': 0, 'male': 0, 'female': 0},
    'classes': {'count': 0, 'students': 0},
    'feeCollection': {'amount': 0, 'total': 0},
    'attendancePercent': 0,
    'announcements': <dynamic>[],
    'activities': <dynamic>[],
    'recentTransactions': <dynamic>[],
    'topStudents': <dynamic>[],
  };

  Map<String, dynamic> _emptyFeeChart() => {
    'total': 0,
    'segments': <dynamic>[],
  };

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    Map<String, dynamic>? summary;
    Map<String, dynamic>? feeChart;

    try {
      final res = await dio.get('/admin/dashboard/summary');
      summary = res.data as Map<String, dynamic>;
    } catch (_) {
      summary = _emptySummary();
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
      _feeChart = feeChart ?? _emptyFeeChart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullName = ref.watch(
      authProvider.select((a) => a.user?.fullName ?? 'Admin'),
    );
    final schoolName = ref.watch(
      authProvider.select((a) => a.user?.schoolName),
    );
    final selectedSchool = ref.watch(selectedSchoolProvider);
    final displaySchool = (schoolName != null && schoolName.isNotEmpty)
        ? schoolName
        : (selectedSchool?.name ?? 'Your School');
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return ColoredBox(
      color: AdminScreenBody.pageBackground,
      child: Column(
        children: [
          _header(fullName, displaySchool),
          Expanded(
            child: AdminScreenBody(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(top: 8, bottom: bottomInset),
                  children: [
                    // Sections settle in top-to-bottom, 70ms apart.
                    EntranceFade(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _hPad),
                        child: _overviewCard(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    EntranceFade(
                      delay: const Duration(milliseconds: 70),
                      child: Column(
                        children: [
                          _sectionHeader(
                            'Quick Access',
                            trailing: 'View All',
                            onTap: () => widget.onTabSelect?.call(4),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            child: _quickAccessGrid(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    EntranceFade(
                      delay: const Duration(milliseconds: 140),
                      child: Column(
                        children: [
                          _sectionHeader(
                            'Top Students',
                            trailing: 'View All',
                            onTap: () => openSmoothPage(
                              context,
                              const AdminReportsScreen(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            child: _topStudentsCard(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    EntranceFade(
                      delay: const Duration(milliseconds: 210),
                      child: Column(
                        children: [
                          _sectionHeader(
                            'Recent Fee Payments',
                            trailing: 'View All',
                            onTap: () => openSmoothPage(
                              context,
                              const AdminFeeCollectionScreen(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            child: _recentPaymentsCard(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    EntranceFade(
                      delay: const Duration(milliseconds: 280),
                      child: Column(
                        children: [
                          _sectionHeader(
                            'Fee Collection Overview',
                            trailingPill: 'This Month',
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _hPad,
                            ),
                            child: _feeCollectionCard(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header — menu + bell/avatar, greeting below
  // ---------------------------------------------------------------------
  Widget _header(String fullName, String school) {
    final announcements =
        (_summary?['announcements'] as List<dynamic>? ?? []).length;

    return AdminScreenHeader(
      eyebrow: '${_greeting()},',
      title: '$fullName 👋',
      // Sits beside three controls, so it starts smaller than a screen name
      // and scales down further if the name is long.
      titleSize: 20,
      subtitle: school,
      // The school name is verified by virtue of being the signed-in tenant.
      subtitleTrailing: const Icon(
        Icons.verified_rounded,
        size: 15,
        color: AppColors.primary,
      ),
      leading: AdminHeaderIconButton(
        icon: Icons.segment_rounded,
        plain: true,
        onTap: _openSidebar,
      ),
      actions: [
        AdminHeaderIconButton(
          icon: Icons.notifications_none_rounded,
          badgeCount: announcements,
          onTap: () =>
              openSmoothPage(context, const AdminAnnouncementsScreen()),
        ),
        _avatarButton(fullName),
      ],
    );
  }

  /// Profile avatar in the header — initials until an avatar URL exists.
  Widget _avatarButton(String fullName) {
    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return PressableScale(
      onTap: () => openSmoothPage(context, const AdminProfileScreen()),
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials.isEmpty ? 'A' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ---------------------------------------------------------------------
  // School Overview — stats live inside the card
  // ---------------------------------------------------------------------
  Widget _overviewCard() {
    if (_summary == null) {
      return const SkeletonBox(height: 176, borderRadius: 26);
    }

    // Uniform shape: icon + value + label. The original card gave Attendance
    // an extra "Today" line, which made its column taller and knocked the
    // other three off a shared baseline.
    final stats =
        <
          ({
            IconData icon,
            num value,
            String suffix,
            String label,
            VoidCallback? onTap,
          })
        >[
          (
            icon: Icons.groups_rounded,
            value: _toInt(_summary?['students']?['count']),
            suffix: '',
            label: 'Students',
            onTap: () => widget.onTabSelect?.call(1),
          ),
          (
            icon: Icons.person_rounded,
            value: _toInt(_summary?['teachers']?['count']),
            suffix: '',
            label: 'Teachers',
            onTap: () => widget.onTabSelect?.call(2),
          ),
          (
            icon: Icons.school_rounded,
            value: _toInt(_summary?['classes']?['count']),
            suffix: '',
            label: 'Classes',
            onTap: () => widget.onTabSelect?.call(3),
          ),
          (
            icon: Icons.fact_check_rounded,
            value: _toInt(_summary?['attendancePercent']),
            suffix: '%',
            label: 'Attendance',
            onTap: () => openSmoothPage(context, const AdminAttendanceScreen()),
          ),
        ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          // Two shadows: a tight contact shadow plus a wide coloured bloom.
          // One flat shadow is what makes a card look pasted on.
          BoxShadow(
            color: AppColors.teacherPrimary.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppColors.teacherPrimary.withValues(alpha: 0.34),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: ColoredBox(
          // Indigo, flat: AppColors.teacherPrimary. Depth comes from the
          // radial blooms and catch-light below rather than a second hue.
          color: AppColors.teacherPrimary,
          child: Stack(
            children: [
              // Light source: a soft bloom off the top-right, falling away
              // rather than the hard-edged circles this had before.
              Positioned(
                right: -70,
                top: -110,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -50,
                bottom: -90,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Catch-light along the top edge — the detail that makes a
              // surface read as glass rather than paint.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'School Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Solid white, not translucent: on indigo even
                              // 92% white measures 4.23:1 and fails AA at this
                              // size. Weight and size carry the hierarchy.
                              const Text(
                                "Today's at-a-glance summary",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _todayPill(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Frosted inner panel: gives the stats a floor to sit on
                    // rather than floating loose in the card.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.07),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      // IntrinsicHeight bounds the row so the dividers can span
                      // it; `stretch` against a ListView's unbounded height
                      // throws and renders blank in release.
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < stats.length; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    // Fades at both ends so it reads as a
                                    // seam, not a hard rule.
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.22),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              Expanded(child: _overviewStat(stats[i])),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayPill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 1),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            // Sits on the pill's own light overlay, so it needs more than the
            // 0.75 that would have been fine against bare indigo.
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(
    ({
      IconData icon,
      num value,
      String suffix,
      String label,
      VoidCallback? onTap,
    })
    s,
  ) {
    return PressableScale(
      onTap: s.onTap,
      pressedScale: 0.93,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bare icon: inside the frosted panel a filled chip per stat reads
          // as four competing boxes. The number is the thing to look at.
          // 90% clears the 3:1 minimum for non-text on indigo.
          Icon(s.icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountUpText(
              value: s.value,
              suffix: s.suffix,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.9,
              ),
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              s.label,
              maxLines: 1,
              // Solid white for AA at 10px on indigo; the light weight and
              // small size keep it subordinate to the number.
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                height: 1.1,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------
  Widget _sectionHeader(
    String title, {
    String? trailing,
    String? trailingPill,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          if (trailingPill != null)
            Row(
              children: [
                Text(
                  trailingPill,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _ink.withValues(alpha: 0.5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Quick Access grid — 4×2
  // ---------------------------------------------------------------------
  Widget _quickAccessGrid() {
    final items =
        <({IconData icon, String label, Color color, VoidCallback onTap})>[
          (
            icon: Icons.groups_rounded,
            label: 'Students',
            color: const Color(0xFF6366F1),
            onTap: () => widget.onTabSelect?.call(1),
          ),
          (
            icon: Icons.person_rounded,
            label: 'Teachers',
            color: const Color(0xFF22C55E),
            onTap: () => widget.onTabSelect?.call(2),
          ),
          (
            icon: Icons.menu_book_rounded,
            label: 'Classes',
            color: const Color(0xFF3B82F6),
            onTap: () => widget.onTabSelect?.call(3),
          ),
          (
            icon: Icons.fact_check_rounded,
            label: 'Attendance',
            color: const Color(0xFFF59E0B),
            onTap: () => openSmoothPage(context, const AdminAttendanceScreen()),
          ),
          (
            icon: Icons.currency_rupee_rounded,
            label: 'Fees',
            color: const Color(0xFF22C55E),
            onTap: () =>
                openSmoothPage(context, const AdminFeeCollectionScreen()),
          ),
          (
            icon: Icons.description_rounded,
            label: 'Exams & Marks',
            color: const Color(0xFFEF4444),
            onTap: () =>
                openSmoothPage(context, const AdminExaminationsScreen()),
          ),
          (
            icon: Icons.campaign_rounded,
            label: 'Announcements',
            color: const Color(0xFF8B5CF6),
            onTap: () =>
                openSmoothPage(context, const AdminAnnouncementsScreen()),
          ),
          (
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            color: const Color(0xFF3B82F6),
            onTap: () => openSmoothPage(context, const AdminReportsScreen()),
          ),
        ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      childAspectRatio: 0.82,
      children: [for (final it in items) _quickAccessCard(it)],
    );
  }

  Widget _quickAccessCard(
    ({IconData icon, String label, Color color, VoidCallback onTap}) it,
  ) {
    return PressableScale(
      onTap: it.onTap,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: it.onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: it.color.withValues(alpha: 0.1),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: it.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(it.icon, color: it.color, size: 21),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Top students — /admin/dashboard/summary already returns `topStudents`
  // grouped by grade (10th, then 11/12 per stream). Nothing displayed it.
  // ---------------------------------------------------------------------
  Widget _topStudentsCard() {
    if (_summary == null) {
      return const SkeletonBox(height: 180, borderRadius: 20);
    }

    final groups = (_summary?['topStudents'] as List<dynamic>? ?? []);
    // Flatten the grade groups and take the strongest few overall.
    final ranked = <Map<String, dynamic>>[];
    for (final g in groups) {
      final group = g as Map<String, dynamic>;
      for (final st in (group['students'] as List<dynamic>? ?? [])) {
        ranked.add({
          ...st as Map<String, dynamic>,
          'groupLabel': group['label'],
        });
      }
    }
    ranked.sort(
      (a, b) => _toDouble(
        b['averagePercent'],
      ).compareTo(_toDouble(a['averagePercent'])),
    );
    final show = ranked.take(4).toList();

    return Container(
      decoration: _cardDecoration(),
      child: show.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No marks recorded yet — rankings appear once exam marks are entered.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < show.length; i++) ...[
                  EntranceFadeItem(
                    index: i,
                    child: _topStudentRow(show[i], i + 1),
                  ),
                  if (i < show.length - 1)
                    const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 14,
                      color: Color(0xFFF0F1F6),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _topStudentRow(Map<String, dynamic> s, int rank) {
    final name = '${s['fullName'] ?? ''}';
    final pct = _toDouble(s['averagePercent']);
    // Gold / silver / bronze for the podium, brand blue after that.
    final medal = switch (rank) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB45309),
      _ => AppColors.primary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: medal,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s['classLabel'] ?? ''} · Roll ${s['rollNumber'] ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: medal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pct.toStringAsFixed(pct >= 100 ? 0 : 1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: medal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Recent fee payments — also already returned by the summary endpoint.
  // ---------------------------------------------------------------------
  Widget _recentPaymentsCard() {
    if (_summary == null) {
      return const SkeletonBox(height: 180, borderRadius: 20);
    }

    final items = (_summary?['recentTransactions'] as List<dynamic>? ?? []);
    final show = items.take(4).toList();

    return Container(
      decoration: _cardDecoration(),
      child: show.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No fee payments recorded yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < show.length; i++) ...[
                  EntranceFadeItem(
                    index: i,
                    child: _paymentRow(show[i] as Map<String, dynamic>),
                  ),
                  if (i < show.length - 1)
                    const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 14,
                      color: Color(0xFFF0F1F6),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _paymentRow(Map<String, dynamic> t) {
    final amount = _toInt(t['amount']);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              size: 19,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${t['studentName'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t['className'] ?? ''} · ${t['method'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money.format(amount),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _relativeTime(t['paidAt']),
                style: TextStyle(
                  fontSize: 10.5,
                  color: _ink.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _relativeTime(dynamic iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse('$iso');
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return DateFormat('d MMM').format(t);
  }

  // ---------------------------------------------------------------------
  // Fee Collection — Collected | ring | Pending
  // ---------------------------------------------------------------------
  Widget _feeCollectionCard() {
    if (_feeChart == null) {
      return const SkeletonBox(height: 150, borderRadius: 20);
    }
    final segments = (_feeChart?['segments'] as List<dynamic>? ?? []);
    int collected = 0;
    int pending = 0;
    for (final raw in segments) {
      final seg = raw as Map<String, dynamic>;
      final label = '${seg['label']}'.toLowerCase();
      if (label.contains('collect')) collected = _toInt(seg['amount']);
      if (label.contains('pending')) pending = _toInt(seg['amount']);
    }
    final total = collected + pending;
    final collectedPct = total > 0 ? (collected / total * 100).round() : 0;
    final pendingPct = total > 0 ? 100 - collectedPct : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _feeStat(
              'Collected',
              _formatCurrency(collected),
              '$collectedPct% of total',
              const Color(0xFF16A34A),
            ),
          ),
          _feeRing(collectedPct),
          Expanded(
            child: _feeStat(
              'Pending',
              _formatCurrency(pending),
              '$pendingPct% of total',
              const Color(0xFFF59E0B),
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeStat(
    String label,
    String amount,
    String sub,
    Color color, {
    bool alignEnd = false,
  }) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            amount,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: textAlign,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _feeRing(int pct) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0xFFEDEFF4),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
            ),
          ),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
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

  String _formatCurrency(dynamic value) => '₹${_formatNumber(value)}';

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
