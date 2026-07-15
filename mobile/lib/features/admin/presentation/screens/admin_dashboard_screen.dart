import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_attendance_screen.dart';
import 'admin_examinations_screen.dart';
import 'admin_fee_collection_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_announcements_screen.dart';
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
  static const _ink = Color(0xFF1A1533);

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _feeChart;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openSidebar() => _scaffoldKey.currentState?.openDrawer();

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

  Map<String, dynamic> _emptyFeeChart() => {'total': 0, 'segments': <dynamic>[]};

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
    final schoolName =
        ref.watch(authProvider.select((a) => a.user?.schoolName));
    final role = ref.watch(authProvider.select((a) => a.user?.role ?? 'ADMIN'));
    final selectedSchool = ref.watch(selectedSchoolProvider);
    final displaySchool = (schoolName != null && schoolName.isNotEmpty)
        ? schoolName
        : (selectedSchool?.name ?? 'Your School');
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5FB),
      drawer: AdminSidebar(onTabSelect: widget.onTabSelect),
      drawerEnableOpenDragGesture: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            _header(fullName, role, displaySchool),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: _overviewCard(),
            ),
            const SizedBox(height: 24),
            _sectionHeader(
              'Quick Access',
              trailing: 'View All',
              onTap: () => widget.onTabSelect?.call(4),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: _quickAccessGrid(),
            ),
            const SizedBox(height: 24),
            _sectionHeader(
              'Recent Activity',
              trailing: 'View All',
              onTap: () =>
                  openSmoothPage(context, const AdminReportsScreen()),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: _recentActivityCard(),
            ),
            const SizedBox(height: 24),
            _sectionHeader('Fee Collection Overview', trailingPill: 'This Month'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: _feeCollectionCard(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header — logo, greeting, notification bell
  // ---------------------------------------------------------------------
  Widget _header(String fullName, String role, String school) {
    final top = MediaQuery.paddingOf(context).top;
    final announcements =
        (_summary?['announcements'] as List<dynamic>? ?? []).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 12, _hPad, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _openSidebar,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7367F0), Color(0xFF5A4FD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6355E0).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_greeting()},',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _ink.withValues(alpha: 0.5),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$fullName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_roleLabel(role)} • $school',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _notificationBell(announcements),
        ],
      ),
    );
  }

  Widget _notificationBell(int count) {
    return GestureDetector(
      onTap: () => openSmoothPage(context, const AdminAnnouncementsScreen()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6355E0).withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: _ink, size: 24),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF5F5FB), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return 'Administrator';
      case 'TEACHER':
        return 'Teacher';
      case 'PARENT':
        return 'Parent';
      default:
        return role;
    }
  }

  // ---------------------------------------------------------------------
  // School Overview — purple gradient stat card
  // ---------------------------------------------------------------------
  Widget _overviewCard() {
    if (_summary == null) {
      return const SkeletonBox(height: 150, borderRadius: 22);
    }

    final stats = <({IconData icon, String value, String label, String? sub})>[
      (
        icon: Icons.groups_rounded,
        value: _formatNumber(_summary?['students']?['count']),
        label: 'Students',
        sub: null,
      ),
      (
        icon: Icons.person_rounded,
        value: _formatNumber(_summary?['teachers']?['count']),
        label: 'Teachers',
        sub: null,
      ),
      (
        icon: Icons.school_rounded,
        value: _formatNumber(_summary?['classes']?['count']),
        label: 'Classes',
        sub: null,
      ),
      (
        icon: Icons.fact_check_rounded,
        value: '${_toInt(_summary?['attendancePercent'])}%',
        label: 'Attendance',
        sub: 'Today',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6FF2), Color(0xFF6355E0), Color(0xFF5344CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6355E0).withValues(alpha: 0.4),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'School Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Today's at-a-glance summary",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: Colors.white.withValues(alpha: 0.9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 58,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                Expanded(child: _overviewStat(stats[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(
      ({IconData icon, String value, String label, String? sub}) s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(s.icon, color: Colors.white, size: 21),
        ),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            s.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (s.sub != null)
          Text(
            s.sub!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
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
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: _ink.withValues(alpha: 0.5)),
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
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _ink.withValues(alpha: 0.5)),
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
    final items = <({IconData icon, String label, Color color, VoidCallback onTap})>[
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
        onTap: () =>
            openSmoothPage(context, const AdminAttendanceScreen()),
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
      children: [
        for (final it in items) _quickAccessCard(it),
      ],
    );
  }

  Widget _quickAccessCard(
      ({IconData icon, String label, Color color, VoidCallback onTap}) it) {
    return Material(
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
                color: const Color(0xFF6355E0).withValues(alpha: 0.06),
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
    );
  }

  // ---------------------------------------------------------------------
  // Recent Activity
  // ---------------------------------------------------------------------
  Widget _recentActivityCard() {
    if (_summary == null) {
      return const SkeletonBox(height: 180, borderRadius: 20);
    }
    final items = (_summary?['activities'] as List<dynamic>? ?? []);
    final show = items.take(4).toList();

    return Container(
      decoration: _cardDecoration(),
      child: show.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No recent activity yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < show.length; i++) ...[
                  _activityRow(show[i] as Map<String, dynamic>),
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

  Widget _activityRow(Map<String, dynamic> item) {
    final action = '${item['action'] ?? 'Activity'}';
    final (icon, color) = _activityIcon(action);
    final actor = '${item['actorName'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    height: 1.3,
                  ),
                ),
                if (actor.isNotEmpty && actor != 'Admin') ...[
                  const SizedBox(height: 2),
                  Text(
                    'by $actor',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRelativeDate(item['createdAt']),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: Color(0xFFC2C8D4)),
        ],
      ),
    );
  }

  (IconData, Color) _activityIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('student')) {
      return (Icons.person_add_alt_1_rounded, const Color(0xFF3B82F6));
    }
    if (a.contains('fee') || a.contains('paid') || a.contains('payment')) {
      return (Icons.currency_rupee_rounded, const Color(0xFF22C55E));
    }
    if (a.contains('attendance')) {
      return (Icons.fact_check_rounded, const Color(0xFF8B5CF6));
    }
    if (a.contains('announcement')) {
      return (Icons.campaign_rounded, const Color(0xFFF59E0B));
    }
    if (a.contains('teacher')) {
      return (Icons.school_rounded, const Color(0xFF22C55E));
    }
    if (a.contains('class')) {
      return (Icons.menu_book_rounded, const Color(0xFF3B82F6));
    }
    return (Icons.bolt_rounded, const Color(0xFF6366F1));
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

  Widget _feeStat(String label, String amount, String sub, Color color,
      {bool alignEnd = false}) {
    final align =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
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
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
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
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF16A34A)),
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
          color: const Color(0xFF6355E0).withValues(alpha: 0.06),
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

  String _formatRelativeDate(dynamic value) {
    final dt = DateTime.tryParse('$value');
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return DateFormat('h:mm a').format(local);
    final diff = now.difference(local);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM').format(local);
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
