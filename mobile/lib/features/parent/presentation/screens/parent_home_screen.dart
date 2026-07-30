import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import 'parent_notifications_screen.dart';

/// Parent home — a bento dashboard. A compact child header, then an attendance
/// ring as the hero metric alongside glanceable Marks and Fees tiles, the next
/// test, and a recent-activity feed.
///
/// All data comes from GET /parent/home, scoped server-side to this student.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key, this.onOpenTab});

  /// Jump to a shell tab (1 Marks, 2 Fees, 3 Chat).
  final void Function(int index)? onOpenTab;

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _headerInk = Color(0xFF1E1B4B);
  static const _pageBg = Color(0xFFF8F9FE);
  static const _hPad = 16.0;

  static const _green = AppColors.statGreen;
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _data == null);
    try {
      final res = await ref.read(dioProvider).get('/parent/home');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(res.data as Map);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your child\'s details. Pull to retry.';
      });
    }
  }

  Map<String, dynamic> get _child =>
      Map<String, dynamic>.from(_data?['child'] as Map? ?? {});
  Map<String, dynamic> get _attendance =>
      Map<String, dynamic>.from(_data?['attendance'] as Map? ?? {});
  Map<String, dynamic> get _marks =>
      Map<String, dynamic>.from(_data?['marks'] as Map? ?? {});
  Map<String, dynamic> get _fees =>
      Map<String, dynamic>.from(_data?['fees'] as Map? ?? {});
  List<dynamic> get _upcomingTests =>
      _data?['upcomingTests'] as List<dynamic>? ?? [];
  List<dynamic> get _activity => _data?['activity'] as List<dynamic>? ?? [];

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _money(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final grouped = head.replaceAllMapped(
      RegExp(r'(\d)(?=(\d\d)+$)'),
      (m) => '${m[1]},',
    );
    return '₹$grouped,$tail';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      color: _pageBg,
      child: RefreshIndicator(
        color: _accent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(_hPad, top + 10, _hPad, 110),
          children: [
            _header(),
            if (_error != null) ...[const SizedBox(height: 12), _errorBanner()],
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              )
            else ...[
              const SizedBox(height: 16),
              EntranceFade(child: _studentCard()),
              const SizedBox(height: 14),
              EntranceFade(
                delay: const Duration(milliseconds: 70),
                child: _bentoRow(),
              ),
              if (_upcomingTests.isNotEmpty) ...[
                const SizedBox(height: 12),
                EntranceFade(
                  delay: const Duration(milliseconds: 120),
                  child: _nextTestStrip(),
                ),
              ],
              const SizedBox(height: 22),
              EntranceFade(
                delay: const Duration(milliseconds: 170),
                child: _activitySection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Compact header
  // ---------------------------------------------------------------------
  Widget _header() {
    final parent = ref.watch(authProvider).user?.fullName ?? 'Parent';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_greeting 👋',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _headerInk.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _headerInk,
                  letterSpacing: -0.4,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _bell(),
      ],
    );
  }

  /// The child identity card — the one bold gradient surface on the page.
  Widget _studentCard() {
    final name = '${_child['fullName'] ?? '—'}';
    final className = '${_child['className'] ?? ''}';
    final roll = _child['rollNumber'];
    final school = '${_child['schoolName'] ?? ''}';
    final avatar = _avatar(_child['avatarUrl'] as String?);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4BD6), Color(0xFF7C6BF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              image: avatar != null
                  ? DecorationImage(image: avatar, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatar == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
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
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (className.isNotEmpty) _heroChip(className),
                    if (roll != null) ...[
                      const SizedBox(width: 6),
                      _heroChip('Roll $roll'),
                    ],
                  ],
                ),
                if (school.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.apartment_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  int get _unread => (_data?['unreadNotifications'] as int?) ?? 0;

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ParentNotificationsScreen()),
    );
    // Reload so the badge clears after they've been marked read.
    _load();
  }

  Widget _bell() {
    return GestureDetector(
      onTap: _openNotifications,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _headerInk,
              size: 21,
            ),
          ),
          if (_unread > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.statOrange,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _error!,
      style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
    ),
  );

  // ---------------------------------------------------------------------
  // Bento: attendance ring + marks + fees
  // ---------------------------------------------------------------------
  Widget _bentoRow() {
    // IntrinsicHeight lets the right column size to its two stacked tiles, then
    // the attendance tile stretches to match — no fixed height to overflow.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _attendanceTile()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _marksTile(),
                const SizedBox(height: 12),
                _feesTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTile() {
    final pct = _attendance['percent'] as int?;
    final color = pct == null
        ? _accent
        : pct >= 75
            ? _green
            : pct >= 50
                ? _amber
                : _red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AttendanceRing(percent: pct, color: color),
          const SizedBox(height: 12),
          const Text(
            'Attendance',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            pct == null
                ? 'Not marked yet'
                : pct >= 90
                    ? 'Excellent'
                    : pct >= 75
                        ? 'Good'
                        : 'Needs attention',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: pct == null ? _ink.withValues(alpha: 0.4) : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _marksTile() {
    final avg = _marks['average'] as int?;
    return _MiniTile(
      onTap: () => widget.onOpenTab?.call(1),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _iconChip(Icons.school_rounded, AppColors.primary),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _ink.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Avg Marks',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 1),
              avg == null
                  ? const Text(
                      '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    )
                  : CountUpText(
                      value: avg,
                      suffix: '%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.05,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feesTile() {
    final due = (_fees['due'] as num?)?.toInt() ?? 0;
    final total = (_fees['total'] as num?)?.toInt() ?? 0;
    final paid = (_fees['paid'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return _MiniTile(
      onTap: () => widget.onOpenTab?.call(2),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _iconChip(Icons.receipt_long_rounded, AppColors.statOrange),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _ink.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total == 0 ? 'Fees' : 'Balance Due',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                total == 0 ? '—' : _money(due),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.1,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: AppColors.statOrange.withValues(
                      alpha: 0.14,
                    ),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.statOrange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon, Color color) => Container(
    height: 30,
    width: 30,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 17, color: color),
  );

  // ---------------------------------------------------------------------
  // Next test
  // ---------------------------------------------------------------------
  Widget _nextTestStrip() {
    final t = Map<String, dynamic>.from(_upcomingTests.first as Map);
    final date = DateTime.tryParse('${t['eventDate'] ?? ''}');
    final now = DateTime.now();
    final days = date == null
        ? null
        : DateTime(
            date.toLocal().year,
            date.toLocal().month,
            date.toLocal().day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final soon = days != null && days <= 2;
    final accent = soon ? _red : _amber;
    final accentInk = soon ? const Color(0xFFB91C1C) : const Color(0xFFB45309);
    final countdown = days == null
        ? ''
        : days <= 0
            ? 'Today'
            : days == 1
                ? 'Tomorrow'
                : 'In $days days';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.16)!],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date == null ? '' : DateFormat('MMM').format(date.toLocal()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  date == null ? '—' : '${date.toLocal().day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next Test',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accentInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t['title'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          if (countdown.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                countdown,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: accentInk,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Activity feed
  // ---------------------------------------------------------------------
  Widget _activitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Activity'),
        const SizedBox(height: 12),
        if (_activity.isEmpty)
          _emptyCard(
            Icons.history_rounded,
            'Nothing yet',
            'Attendance and fee updates will appear here.',
          )
        else
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                for (var i = 0; i < _activity.length; i++)
                  _activityRow(
                    Map<String, dynamic>.from(_activity[i] as Map),
                    last: i == _activity.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _activityRow(Map<String, dynamic> a, {required bool last}) {
    final type = '${a['type']}';
    final date = DateTime.tryParse('${a['date'] ?? ''}');
    final dateLabel = date == null
        ? ''
        : DateFormat('d MMM').format(date.toLocal());

    late final IconData icon;
    late final Color color;
    late final String title;
    late final String subtitle;

    if (type == 'fee') {
      icon = Icons.check_circle_rounded;
      color = _green;
      title = 'Fee paid';
      subtitle = '${a['label'] ?? ''}';
    } else {
      final status = '${a['status']}';
      subtitle = 'Attendance';
      if (status == 'ABSENT') {
        icon = Icons.cancel_rounded;
        color = _red;
        title = 'Marked absent';
      } else if (status == 'LEAVE') {
        icon = Icons.event_busy_rounded;
        color = _amber;
        title = 'On leave';
      } else {
        icon = Icons.check_circle_rounded;
        color = _green;
        title = 'Marked present';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFF3F3F8)),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
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
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _sectionHeader(String text) => Row(
    children: [
      Container(
        height: 17,
        width: 4,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B4BD6), Color(0xFF7C6BF0)],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.3,
        ),
      ),
    ],
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFEFEFF6)),
    boxShadow: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  Widget _emptyCard(IconData icon, String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 34, color: _accent.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _ink.withValues(alpha: 0.5)),
        ),
      ],
    ),
  );

  ImageProvider? _avatar(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }
}

/// Animated circular attendance gauge with the percentage in the center.
class _AttendanceRing extends StatelessWidget {
  const _AttendanceRing({required this.percent, required this.color});

  final int? percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final target = (percent ?? 0) / 100;

    return SizedBox(
      height: 84,
      width: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 84,
            width: 84,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CircularProgressIndicator(
                value: percent == null ? null : v,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          if (percent == null)
            Text(
              '—',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            )
          else
            CountUpText(
              value: percent!,
              suffix: '%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1533),
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// A tappable bento tile with a press squish.
class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.child,
    required this.decoration,
    this.onTap,
  });

  final Widget child;
  final BoxDecoration decoration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: decoration,
        child: child,
      ),
    );
  }
}
