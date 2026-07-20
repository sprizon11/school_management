import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Full marks list for the child, grouped by exam/term. Read-only — the data
/// comes from GET /parent/marks, scoped server-side to this parent's student.
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

  /// Marks grouped by exam name, newest first (the API already sorts by term).
  Map<String, List<Map<String, dynamic>>> get _byTerm {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final raw in _marks ?? []) {
      final m = Map<String, dynamic>.from(raw as Map);
      out.putIfAbsent('${m['termLabel'] ?? 'Exam'}', () => []).add(m);
    }
    return out;
  }

  int? get _overallAverage {
    final all = _marks ?? [];
    if (all.isEmpty) return null;
    final sum = all.fold<int>(
      0,
      (t, m) => t + ((m as Map)['percent'] as int? ?? 0),
    );
    return (sum / all.length).round();
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
                ? const Center(child: CircularProgressIndicator(color: _accent))
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
                  'All exam results',
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
          Text(
            '$avg%',
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
    if (_error != null) {
      return ListView(children: [_message(_error!)]);
    }
    final groups = _byTerm;
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _message(
            'No marks recorded yet.\nResults appear here once teachers enter them.',
          ),
        ],
      );
    }

    final terms = groups.keys.toList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_hPad, 6, _hPad, 110),
      itemCount: terms.length,
      itemBuilder: (_, i) => EntranceFadeItem(
        index: i,
        child: _termCard(terms[i], groups[terms[i]]!),
      ),
    );
  }

  Widget _termCard(String term, List<Map<String, dynamic>> rows) {
    final termAvg =
        (rows.fold<int>(0, (t, m) => t + (m['percent'] as int? ?? 0)) /
                rows.length)
            .round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        children: [
          // Term header strip.
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
                // Score bar — a quick visual read of the percentage.
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

  Color _colorFor(int percent) {
    if (percent >= 75) return AppColors.statGreen;
    if (percent >= 35) return AppColors.primary;
    return const Color(0xFFEF4444);
  }

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
