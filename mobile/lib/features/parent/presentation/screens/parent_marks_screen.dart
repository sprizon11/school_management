import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Full marks for the child: an overall average, a best/weakest-subject
/// summary, a per-subject bar chart, then results grouped by exam. Everything
/// derives from GET /parent/marks (a flat list); the subject roll-ups are
/// computed here on the client.
class ParentMarksScreen extends ConsumerStatefulWidget {
  const ParentMarksScreen({super.key});

  @override
  ConsumerState<ParentMarksScreen> createState() => _ParentMarksScreenState();
}

class _ParentMarksScreenState extends ConsumerState<ParentMarksScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _headerInk = Color(0xFF1E1B4B);
  static const _hPad = 16.0;

  List<dynamic>? _marks;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _marks == null);
    try {
      final res = await ref.read(dioProvider).get('/parent/marks');
      if (!mounted) return;
      setState(() {
        _marks = res.data as List<dynamic>? ?? [];
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load marks. Pull to retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _all => (_marks ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  /// Marks grouped by exam name (the API already sorts by term).
  Map<String, List<Map<String, dynamic>>> get _byTerm {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final m in _all) {
      out.putIfAbsent('${m['termLabel'] ?? 'Exam'}', () => []).add(m);
    }
    return out;
  }

  /// Average percent per subject, best first.
  List<({String subject, int avg, int count})> get _bySubject {
    final sums = <String, List<int>>{};
    for (final m in _all) {
      final s = '${m['subject'] ?? ''}';
      (sums[s] ??= []).add(m['percent'] as int? ?? 0);
    }
    final list = sums.entries
        .map(
          (e) => (
            subject: e.key,
            avg: (e.value.reduce((a, b) => a + b) / e.value.length).round(),
            count: e.value.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));
    return list;
  }

  int? get _overallAverage {
    if (_all.isEmpty) return null;
    final sum = _all.fold<int>(0, (t, m) => t + (m['percent'] as int? ?? 0));
    return (sum / _all.length).round();
  }

  Color _colorFor(int percent) {
    if (percent >= 75) return AppColors.statGreen;
    if (percent >= 35) return AppColors.primary;
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: const Color(0xFFF8F9FE),
      child: Column(
        children: [
          _header(top),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _accent),
                  )
                : RefreshIndicator(
                    color: _accent,
                    onRefresh: _load,
                    child: _content(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(double top) {
    final avg = _overallAverage;
    return Padding(
      padding: EdgeInsets.fromLTRB(_hPad, top + 10, _hPad, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Marks',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _headerInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Performance & results',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _headerInk.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (avg != null) _averageBadge(avg),
        ],
      ),
    );
  }

  Widget _averageBadge(int avg) {
    final color = _colorFor(avg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CountUpText(
            value: avg,
            suffix: '%',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.05,
            ),
          ),
          Text(
            'Average',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_error != null) return ListView(children: [_message(_error!)]);
    final terms = _byTerm;
    if (terms.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _message(
            'No marks recorded yet.\nResults appear here once teachers enter them.',
          ),
        ],
      );
    }

    final subjects = _bySubject;
    final termKeys = terms.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_hPad, 6, _hPad, 110),
      children: [
        if (subjects.length >= 2) ...[
          EntranceFade(child: _summaryCard(subjects)),
          const SizedBox(height: 20),
        ],
        EntranceFade(
          delay: const Duration(milliseconds: 60),
          child: _sectionHeader('By Subject'),
        ),
        const SizedBox(height: 12),
        EntranceFade(
          delay: const Duration(milliseconds: 90),
          child: _subjectChart(subjects),
        ),
        const SizedBox(height: 22),
        EntranceFade(
          delay: const Duration(milliseconds: 120),
          child: _sectionHeader('By Exam'),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < termKeys.length; i++)
          EntranceFadeItem(
            index: i,
            child: _termCard(termKeys[i], terms[termKeys[i]]!),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  Widget _summaryCard(List<({String subject, int avg, int count})> subjects) {
    final best = subjects.first;
    final weak = subjects.last;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _summaryHalf(
              icon: Icons.trending_up_rounded,
              color: AppColors.statGreen,
              label: 'Strongest',
              subject: best.subject,
              avg: best.avg,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: const Color(0xFFEFEFF6),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: _summaryHalf(
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFEF4444),
              label: 'Needs work',
              subject: weak.subject,
              avg: weak.avg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryHalf({
    required IconData icon,
    required Color color,
    required String label,
    required String subject,
    required int avg,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: 0.5),
                ),
              ),
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Text(
                '$avg%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  Widget _subjectChart(List<({String subject, int avg, int count})> subjects) {
    // Order by subject name for a stable axis; cap at 6 so bars stay readable.
    final shown = subjects.take(6).toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
    const maxH = 72.0;

    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final s in shown) _bar(s.subject, s.avg, maxH),
        ],
      ),
    );
  }

  Widget _bar(String subject, int avg, double maxH) {
    final color = _colorFor(avg);
    final h = (avg / 100 * maxH).clamp(6.0, maxH);
    final short = subject.length <= 4
        ? subject
        : subject.substring(0, 4);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$avg',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            // The bar grows on entrance.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: h),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Container(
                width: double.infinity,
                height: v,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.55)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: _ink.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _termCard(String term, List<Map<String, dynamic>> rows) {
    final termAvg =
        (rows.fold<int>(0, (t, m) => t + (m['percent'] as int? ?? 0)) /
                rows.length)
            .round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    term,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorFor(termAvg).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Avg $termAvg%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _colorFor(termAvg),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            _markRow(rows[i], last: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _markRow(Map<String, dynamic> m, {required bool last}) {
    final percent = m['percent'] as int? ?? 0;
    final color = _colorFor(percent);
    final remarks = '${m['remarks'] ?? ''}';

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
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${m['grade'] ?? '-'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
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
                  '${m['subject'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (remarks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    remarks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 5,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${m['marks']} / ${m['maxMarks']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
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

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: Column(
      children: [
        Icon(
          Icons.assignment_outlined,
          size: 44,
          color: _accent.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: _ink.withValues(alpha: 0.55),
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
