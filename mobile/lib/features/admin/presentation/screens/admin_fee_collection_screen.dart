import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminFeeCollectionScreen extends ConsumerStatefulWidget {
  const AdminFeeCollectionScreen({super.key});

  @override
  ConsumerState<AdminFeeCollectionScreen> createState() =>
      _AdminFeeCollectionScreenState();
}

class _AdminFeeCollectionScreenState extends ConsumerState<AdminFeeCollectionScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/fees/overview');
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmt(dynamic n) => '₹${_formatNum(_toInt(n))}';

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  String _formatNum(int n) {
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

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final payments = _data?['recentPayments'] as List<dynamic>? ?? [];

    return AdminSubPageScaffold(
      title: 'Fee Collection',
      subtitle: 'Monitor payments and pending fees',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AdminPremiumCard(
                    child: Column(
                      children: [
                        _feeRow(
                          'Collected',
                          _fmt(summary['collected']),
                          '${summary['paidCount'] ?? 0} paid',
                          const Color(0xFF22A750),
                        ),
                        const Divider(height: 24),
                        _feeRow(
                          'Pending',
                          _fmt(summary['pending']),
                          '${summary['pendingCount'] ?? 0} pending',
                          const Color(0xFFF5A623),
                        ),
                        const Divider(height: 24),
                        _feeRow(
                          'Upcoming',
                          _fmt(summary['upcoming']),
                          'Scheduled dues',
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recent Payments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (payments.isEmpty)
                    const AdminPremiumCard(
                      child: Text(
                        'No recent payments found.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ...payments.map((p) {
                      final m = p as Map<String, dynamic>;
                      final date = DateTime.tryParse('${m['paidAt']}');
                      return AdminListTilePremium(
                        title: '${m['studentName']}',
                        subtitle: date != null
                            ? DateFormat('dd MMM yyyy · hh:mm a').format(date.toLocal())
                            : '${m['method']}',
                        trailing: _fmt(m['amount']),
                        leadingIcon: Icons.payments_rounded,
                        leadingColor: const Color(0xFF22A750),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _feeRow(String label, String amount, String sub, Color color) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.account_balance_wallet_rounded, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }
}
