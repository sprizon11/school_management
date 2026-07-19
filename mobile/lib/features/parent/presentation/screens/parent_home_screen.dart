import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Parent home: who the child is, how they're doing, what's next.
///
/// Everything here comes from GET /parent/home, scoped server-side to the one
/// student linked to this account.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key, this.onOpenMessages});

  /// Lets the quick actions jump to the shell's Messages tab.
  final VoidCallback? onOpenMessages;

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _headerInk = Color(0xFF1E1B4B);
  static const _pageBg = Color(0xFFF8F9FE);
  static const _headerStart = Color(0xFF5B4BD6);
  static const _headerEnd = Color(0xFF7C6BF0);
  static const _hPad = 16.0;

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
  List<dynamic> get _homework => _data?['homework'] as List<dynamic>? ?? [];
  Map<String, dynamic>? get _announcement {
    final a = _data?['announcement'];
    return a == null ? null : Map<String, dynamic>.from(a as Map);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final parentName = ref.watch(authProvider).user?.fullName ?? 'Parent';

    return Container(
      color: _pageBg,
      child: RefreshIndicator(
        color: _accent,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _header(parentName),
            if (_error != null) _errorBanner(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              )
            else ...[
              const SizedBox(height: 14),
              EntranceFade(child: _childCard()),
              const SizedBox(height: 14),
              EntranceFade(
                delay: const Duration(milliseconds: 60),
                child: _statsRow(),
              ),
              if (_announcement != null) ...[
                const SizedBox(height: 18),
                EntranceFade(
                  delay: const Duration(milliseconds: 100),
                  child: _updateBanner(),
                ),
              ],
              const SizedBox(height: 24),
              EntranceFade(
                delay: const Duration(milliseconds: 140),
                child: _marksSection(),
              ),
              const SizedBox(height: 24),
              EntranceFade(
                delay: const Duration(milliseconds: 180),
                child: _homeworkSection(),
              ),
              const SizedBox(height: 24),
              EntranceFade(
                delay: const Duration(milliseconds: 220),
                child: _quickActions(),
              ),
              // Clears the floating nav bar.
              const SizedBox(height: 110),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Light header — same construction as the teacher dashboard: eyebrow
  // greeting, dark ink name, small status pill, white circular bell.
  // ---------------------------------------------------------------------
  Widget _header(String parentName) {
    final top = MediaQuery.paddingOf(context).top;
    final className = '${_child['className'] ?? ''}';

    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 10, _hPad, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_greeting, 👋',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _headerInk.withValues(alpha: 0.5),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _headerInk,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                if (className.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          size: 11,
                          color: _accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          className,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _bell(),
        ],
      ),
    );
  }

  Widget _bell() {
    final hasUpdate = _announcement != null;
    return Stack(
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
                color: _accent.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: _headerInk,
            size: 22,
          ),
        ),
        if (hasUpdate)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              height: 12,
              width: 12,
              decoration: BoxDecoration(
                color: AppColors.statOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Child identity card — overlaps the header
  // ---------------------------------------------------------------------
  Widget _childCard() {
    final name = '${_child['fullName'] ?? '—'}';
    final className = '${_child['className'] ?? ''}';
    final roll = _child['rollNumber'];
    final school = '${_child['schoolName'] ?? ''}';
    final avatar = _avatar(_child['avatarUrl'] as String?);

    // The colour moved off the header and onto this card, so the child — not
    // the greeting — is the first thing the eye lands on.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _hPad),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_headerStart, _headerEnd],
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
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
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
                      fontSize: 24,
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
                    _heroChip(className),
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

  Widget _heroChip(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
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
  }

  // ---------------------------------------------------------------------
  // Four stat tiles — horizontally scrollable so nothing is squeezed
  // ---------------------------------------------------------------------
  /// Three compact tiles, sized to fit the width — no horizontal scrolling,
  /// so nothing is hidden off the right edge.
  Widget _statsRow() {
    final pct = _attendance['percent'];
    final avg = _marks['average'];
    final absentMonth = _attendance['absentThisMonth'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      // IntrinsicHeight gives the Row a bounded height so the tiles can
      // stretch to match each other. Without it, `stretch` inside a
      // vertically-scrolling ListView resolves to an infinite height and the
      // whole list below this point fails to lay out.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _statTile(
                icon: Icons.event_available_rounded,
                color: AppColors.statGreen,
                label: 'Attendance',
                // Dash, not 0% — nothing marked yet is not zero attendance.
                value: pct == null ? '—' : '$pct%',
                note: pct == null ? 'Not marked' : _attendanceNote(pct as int),
                noteColor: pct == null
                    ? _ink.withValues(alpha: 0.4)
                    : AppColors.statGreen,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _statTile(
                icon: Icons.trending_up_rounded,
                color: AppColors.primary,
                label: 'Avg Marks',
                value: avg == null ? '—' : '$avg%',
                note: avg == null ? 'No marks' : _marksNote(avg as int),
                noteColor: avg == null
                    ? _ink.withValues(alpha: 0.4)
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _statTile(
                icon: Icons.person_off_rounded,
                color: AppColors.statPink,
                label: 'Absences',
                value: '$absentMonth',
                note: 'This Month',
                noteColor: AppColors.statPink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _attendanceNote(int pct) {
    if (pct >= 90) return 'Excellent';
    if (pct >= 75) return 'Good';
    return 'Needs care';
  }

  String _marksNote(int pct) {
    if (pct >= 85) return 'Very Good';
    if (pct >= 70) return 'Good';
    if (pct >= 40) return 'Fair';
    return 'Needs work';
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String note,
    required Color noteColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: _cardDecoration(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: _ink.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          // scaleDown keeps "100%" from wrapping in the narrow tile.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: noteColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _updateBanner() {
    final a = _announcement!;
    final date = DateTime.tryParse('${a['eventDate'] ?? a['createdAt']}');
    final dateLabel = date == null
        ? ''
        : DateFormat('EEEE, d MMM').format(date.toLocal());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _hPad),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_headerStart, _headerEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: _headerStart,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'School Update',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a['title'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _marksSection() {
    final recent = _marks['recent'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Marks'),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _emptyCard(
            Icons.assignment_outlined,
            'No marks yet',
            'Results appear here once teachers record them.',
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: _hPad),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++)
                  _markRow(
                    Map<String, dynamic>.from(recent[i] as Map),
                    last: i == recent.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Subject glyphs are matched by name so the rows read at a glance.
  IconData _subjectIcon(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return Icons.calculate_rounded;
    if (s.contains('science') || s.contains('physic') || s.contains('chem')) {
      return Icons.science_rounded;
    }
    if (s.contains('bio')) return Icons.eco_rounded;
    if (s.contains('english') || s.contains('lang')) {
      return Icons.menu_book_rounded;
    }
    if (s.contains('social') || s.contains('history') || s.contains('geo')) {
      return Icons.public_rounded;
    }
    if (s.contains('comp') || s.contains('it')) return Icons.computer_rounded;
    return Icons.school_rounded;
  }

  Widget _markRow(Map<String, dynamic> m, {required bool last}) {
    final percent = m['percent'] as int? ?? 0;
    final color = percent >= 75
        ? AppColors.statGreen
        : percent >= 35
        ? AppColors.primary
        : const Color(0xFFEF4444);
    final subject = '${m['subject'] ?? ''}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFF0F1F6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_subjectIcon(subject), size: 20, color: color),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m['termLabel'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${m['marks']} / ${m['maxMarks']}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _homeworkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Upcoming Homework'),
        const SizedBox(height: 10),
        if (_homework.isEmpty)
          _emptyCard(
            Icons.menu_book_outlined,
            'Nothing due',
            'Homework with a future due date shows up here.',
          )
        else
          for (var i = 0; i < _homework.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _homework.length - 1 ? 0 : 8,
              ),
              child: _homeworkCard(
                Map<String, dynamic>.from(_homework[i] as Map),
              ),
            ),
      ],
    );
  }

  Widget _homeworkCard(Map<String, dynamic> h) {
    final due = DateTime.tryParse('${h['dueDate']}');
    final label = due == null ? '' : DateFormat('d MMM').format(due.toLocal());
    final desc = '${h['description'] ?? ''}';
    const amber = Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _hPad),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_note_rounded, size: 22, color: amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${h['title'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _ink.withValues(alpha: 0.6),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _quickActions() {
    final tiles =
        <({IconData icon, Color color, String label, VoidCallback? tap})>[
          (
            icon: Icons.forum_rounded,
            color: _accent,
            label: 'Message\nTeacher',
            tap: widget.onOpenMessages,
          ),
          (
            icon: Icons.assignment_rounded,
            color: AppColors.primary,
            label: 'All\nMarks',
            tap: () => _snack('Full marks list — coming soon'),
          ),
          (
            icon: Icons.event_note_rounded,
            color: AppColors.statGreen,
            label: 'Attendance\nLog',
            tap: () => _snack('Attendance log — coming soon'),
          ),
          (
            icon: Icons.campaign_rounded,
            color: AppColors.statOrange,
            label: 'School\nNotices',
            tap: () => _snack('Notices — coming soon'),
          ),
        ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: tiles[i].tap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      Icon(tiles[i].icon, size: 24, color: tiles[i].color),
                      const SizedBox(height: 8),
                      Text(
                        tiles[i].label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _hPad),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _ink,
        letterSpacing: -0.3,
      ),
    ),
  );

  BoxDecoration _cardDecoration({double radius = 18}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFEFEFF6)),
    boxShadow: [
      BoxShadow(
        color: _accent.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  Widget _emptyCard(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: _hPad),
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
  }

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
