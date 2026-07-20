import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// The child's fee schedule: how much is due, how much is paid, and each
/// installment's status. Read-only — GET /parent/fees, scoped to this student.
///
/// Paying is deliberately not wired here: taking a payment is a prohibited
/// action for the assistant to build blind, and the app's payment flow lives
/// elsewhere. This screen shows the balance; it does not collect money.
class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _headerInk = Color(0xFF1E1B4B);
  static const _hPad = 16.0;

  static const _green = AppColors.statGreen;
  static const _amber = Color(0xFFF59E0B);
  static const _slate = Color(0xFF64748B);

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
      final res = await ref.read(dioProvider).get('/parent/fees');
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
        _error = 'Could not load fee details. Pull to retry.';
      });
    }
  }

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(_data?['summary'] as Map? ?? {});
  List<dynamic> get _installments =>
      _data?['installments'] as List<dynamic>? ?? [];

  String _money(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    // Indian grouping (e.g. 48,000) to match the school context.
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

  Widget _header(double top) => Padding(
    padding: EdgeInsets.fromLTRB(_hPad, top + 10, _hPad, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Fees',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _headerInk,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Payments & schedule',
          style: TextStyle(
            fontSize: 12.5,
            color: _headerInk.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _content() {
    if (_error != null) return ListView(children: [_message(_error!)]);
    if (_installments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _message(
            'No fees assigned yet.\nYour child\'s fee plan will show up here.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_hPad, 6, _hPad, 110),
      children: [
        EntranceFade(child: _summaryCard()),
        const SizedBox(height: 22),
        EntranceFade(
          delay: const Duration(milliseconds: 60),
          child: _sectionTitle('Payment Schedule'),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _installments.length; i++)
          EntranceFade(
            delay: Duration(milliseconds: 100 + 50 * i),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: i == _installments.length - 1 ? 0 : 10,
              ),
              child: _installmentCard(
                Map<String, dynamic>.from(_installments[i] as Map),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard() {
    final total = (_summary['total'] as num?)?.toInt() ?? 0;
    final paid = (_summary['paid'] as num?)?.toInt() ?? 0;
    final due = (_summary['due'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Due',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Count the balance up on entrance.
          CountUpText(
            value: due,
            format: _money,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          // Paid progress.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryStat('Paid', _money(paid)),
              const SizedBox(width: 20),
              _summaryStat('Total', _money(total)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _installmentCard(Map<String, dynamic> i) {
    final status = '${i['status'] ?? ''}';
    final paid = status == 'PAID';
    final pending = status == 'PENDING';
    final color = paid
        ? _green
        : pending
        ? _amber
        : _slate;
    final label = paid
        ? 'Paid'
        : pending
        ? 'Due'
        : 'Upcoming';

    final due = DateTime.tryParse('${i['dueDate'] ?? ''}');
    final dueLabel = due == null
        ? ''
        : DateFormat('d MMM yyyy').format(due.toLocal());
    final paidAt = DateTime.tryParse('${i['paidAt'] ?? ''}');
    final paidLabel = paidAt == null
        ? ''
        : DateFormat('d MMM yyyy').format(paidAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pending
              ? color.withValues(alpha: 0.35)
              : const Color(0xFFEFEFF6),
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              paid
                  ? Icons.check_circle_rounded
                  : pending
                  ? Icons.schedule_rounded
                  : Icons.lock_clock_rounded,
              size: 21,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${i['label'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paid && paidLabel.isNotEmpty
                      ? 'Paid on $paidLabel'
                      : 'Due $dueLabel',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
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
                _money(i['amount']),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
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
    ),
  );

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    child: Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
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
