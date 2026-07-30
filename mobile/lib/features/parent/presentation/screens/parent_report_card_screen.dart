import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Per-term report cards built from the child's marks (GET /parent/report-cards):
/// subject breakdown, total, percentage, grade, class rank and result.
class ParentReportCardScreen extends ConsumerStatefulWidget {
  const ParentReportCardScreen({super.key});

  @override
  ConsumerState<ParentReportCardScreen> createState() =>
      _ParentReportCardScreenState();
}

class _ParentReportCardScreenState
    extends ConsumerState<ParentReportCardScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _green = AppColors.statGreen;
  static const _red = Color(0xFFEF4444);

  Map<String, dynamic>? _data;
  bool _loading = true;
  int _term = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _data == null);
    try {
      final res = await ref.read(dioProvider).get('/parent/report-cards');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(res.data as Map);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _child =>
      Map<String, dynamic>.from(_data?['child'] as Map? ?? {});
  List<dynamic> get _cards => _data?['cards'] as List<dynamic>? ?? [];

  Color _gradeColor(int pct) {
    if (pct >= 75) return _green;
    if (pct >= 35) return AppColors.primary;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Report Card'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: _cards.isEmpty ? _empty() : _content(),
            ),
    );
  }

  Widget _content() {
    if (_term >= _cards.length) _term = 0;
    final card = Map<String, dynamic>.from(_cards[_term] as Map);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (_cards.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final term = '${(_cards[i] as Map)['term'] ?? ''}';
                final active = i == _term;
                return GestureDetector(
                  onTap: () => setState(() => _term = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? _accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? _accent : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      term,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : _ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        EntranceFade(key: ValueKey(_term), child: _reportCard(card)),
      ],
    );
  }

  Widget _reportCard(Map<String, dynamic> card) {
    final subjects = card['subjects'] as List<dynamic>? ?? [];
    final pct = card['percentage'] as int? ?? 0;
    final color = _gradeColor(pct);
    final pass = '${card['result']}' == 'PASS';
    final rank = card['rank'];
    final classSize = card['classSize'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFEFF6)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5B4BD6), Color(0xFF7C6BF0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  '${_child['schoolName'] ?? ''}'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Report Card · ${card['term'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _headMeta('Student', '${_child['fullName'] ?? ''}'),
                    _headMeta('Class', '${_child['className'] ?? ''}'),
                    _headMeta('Roll', '${_child['rollNumber'] ?? '—'}'),
                  ],
                ),
              ],
            ),
          ),
          // Subject table
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _tableHeader(),
                for (var i = 0; i < subjects.length; i++)
                  _subjectRow(
                    Map<String, dynamic>.from(subjects[i] as Map),
                    i,
                  ),
                const Divider(height: 20, color: Color(0xFFECECF3)),
                _totalRow(card),
              ],
            ),
          ),
          // Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: _summaryStat(
                    'Percentage',
                    child: CountUpText(
                      value: pct,
                      suffix: '%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                _divider(),
                Expanded(
                  child: _summaryStat(
                    'Grade',
                    child: Text(
                      '${card['overallGrade'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                _divider(),
                Expanded(
                  child: _summaryStat(
                    'Rank',
                    child: Text(
                      rank == null ? '—' : '$rank/$classSize',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Result stamp
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: (pass ? _green : _red).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Text(
              pass ? 'RESULT: PASS' : 'RESULT: FAIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: pass
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headMeta(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _tableHeader() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        const Expanded(
          flex: 5,
          child: Text(
            'SUBJECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'MARKS',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.4,
            ),
          ),
        ),
        const Expanded(
          flex: 2,
          child: Text(
            'GRADE',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _subjectRow(Map<String, dynamic> s, int i) {
    final pct = s['percent'] as int? ?? 0;
    final color = _gradeColor(pct);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: i.isEven
                ? Colors.transparent
                : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              '${s['subject'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${s['marks']} / ${s['maxMarks']}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${s['grade'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(Map<String, dynamic> card) => Row(
    children: [
      const Expanded(
        flex: 5,
        child: Text(
          'Total',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          '${card['totalObtained']} / ${card['totalMax']}',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      const Expanded(flex: 2, child: SizedBox()),
    ],
  );

  Widget _summaryStat(String label, {required Widget child}) => Column(
    children: [
      child,
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9CA3AF),
        ),
      ),
    ],
  );

  Widget _divider() => Container(
    width: 1,
    height: 34,
    color: const Color(0xFFECECF3),
  );

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      Icon(
        Icons.assignment_outlined,
        size: 46,
        color: _accent.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No report cards yet',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink.withValues(alpha: 0.6),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          'They appear once exam marks are recorded.',
          style: TextStyle(fontSize: 12, color: _ink.withValues(alpha: 0.45)),
        ),
      ),
    ],
  );
}
