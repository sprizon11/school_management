import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/subscription_pricing.dart';
import '../widgets/admin_sub_page.dart';

class AdminSubscriptionScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionScreen> createState() =>
      _AdminSubscriptionScreenState();
}

class _AdminSubscriptionScreenState extends ConsumerState<AdminSubscriptionScreen> {
  bool _loading = true;
  bool _subscribing = false;
  bool _isActive = false;
  String? _activeUntil;
  int _students = 0;
  int _teachers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final schoolId = ref.read(authProvider).user?.schoolId ?? '';

    try {
      final res = await ref.read(dioProvider).get('/admin/dashboard/summary');
      final data = res.data as Map<String, dynamic>;
      final students = data['students'] as Map<String, dynamic>? ?? {};
      final teachers = data['teachers'] as Map<String, dynamic>? ?? {};
      _students = (students['count'] as num?)?.toInt() ?? 0;
      _teachers = (teachers['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      _students = 0;
      _teachers = 0;
    }

    final prefs = await SharedPreferences.getInstance();
    _isActive = prefs.getBool('subscription_active_$schoolId') ?? false;
    _activeUntil = prefs.getString('subscription_until_$schoolId');

    if (!mounted) return;
    setState(() => _loading = false);
  }

  SubscriptionQuote get _quote => SubscriptionPricing.calculate(
        studentCount: _students,
        teacherCount: _teachers,
      );

  Future<void> _subscribe() async {
    final quote = _quote;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutSheet(quote: quote),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _subscribing = true);
    final schoolId = ref.read(authProvider).user?.schoolId ?? '';
    final until = DateTime.now().add(const Duration(days: 30));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('subscription_active_$schoolId', true);
    await prefs.setString('subscription_until_$schoolId', until.toIso8601String());
    await prefs.setInt('subscription_amount_$schoolId', quote.monthlyTotal);

    if (!mounted) return;
    setState(() {
      _subscribing = false;
      _isActive = true;
      _activeUntil = until.toIso8601String();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription activated for 30 days. Thank you!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final schoolName = ref.watch(authProvider.select((a) => a.user?.schoolName ?? 'Your school'));

    return AdminSubPageScaffold(
      title: 'Subscription',
      subtitle: 'School app licensing & billing',
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_isActive) _activeBanner(),
                  _planHero(schoolName, quote),
                  const SizedBox(height: 16),
                  const AdminSectionTitle('Pricing', icon: Icons.sell_outlined),
                  _pricingCard(quote),
                  const SizedBox(height: 16),
                  const AdminSectionTitle('Your bill estimate', icon: Icons.receipt_long_outlined),
                  _billBreakdown(quote),
                  const SizedBox(height: 16),
                  _bulkNote(quote),
                  const SizedBox(height: 24),
                  AdminPrimaryButton(
                    label: _isActive ? 'Renew subscription' : 'Subscribe now',
                    icon: Icons.verified_user_rounded,
                    loading: _subscribing,
                    onPressed: _subscribe,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Billed monthly based on active students and teachers in your school. '
                    'Student rate drops to ${SubscriptionPricing.formatInr(SubscriptionPricing.bulkStudentRate)} '
                    'when you exceed ${SubscriptionPricing.bulkStudentThreshold} students.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _activeBanner() {
    final until = _activeUntil != null ? DateTime.tryParse(_activeUntil!) : null;
    final untilLabel = until != null
        ? '${until.day}/${until.month}/${until.year}'
        : 'Active';

    return AdminPremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subscription active',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  'Valid until $untilLabel',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planHero(String schoolName, SubscriptionQuote quote) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0835B8), Color(0xFF1B5FFF), Color(0xFF5B8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'SMARTUP PLAN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            schoolName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${quote.studentCount} students · ${quote.teacherCount} teachers',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                SubscriptionPricing.formatInr(quote.monthlyTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ month',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pricingCard(SubscriptionQuote quote) {
    return AdminPremiumCard(
      child: Column(
        children: [
          _priceRow(
            'Per student',
            SubscriptionPricing.formatInr(quote.studentRate),
            quote.isBulkStudentRate ? 'Bulk rate (1200+ students)' : 'Standard rate',
            Icons.groups_rounded,
            const Color(0xFF5B6CFF),
          ),
          const Divider(height: 24),
          _priceRow(
            'Per teacher',
            SubscriptionPricing.formatInr(SubscriptionPricing.teacherRate),
            'All teaching staff',
            Icons.school_rounded,
            const Color(0xFF3CCB6F),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String title,
    String price,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        Text(
          '$price/mo',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _billBreakdown(SubscriptionQuote quote) {
    return AdminPremiumCard(
      child: Column(
        children: [
          _billLine(
            'Students (${quote.studentCount} × ${SubscriptionPricing.formatInr(quote.studentRate)})',
            SubscriptionPricing.formatInr(quote.studentTotal),
          ),
          const SizedBox(height: 10),
          _billLine(
            'Teachers (${quote.teacherCount} × ${SubscriptionPricing.formatInr(quote.teacherRate)})',
            SubscriptionPricing.formatInr(quote.teacherTotal),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _billLine('Monthly total', SubscriptionPricing.formatInr(quote.monthlyTotal), bold: true),
        ],
      ),
    );
  }

  Widget _billLine(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? const Color(0xFF111827) : AppColors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: bold ? AppColors.primary : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _bulkNote(SubscriptionQuote quote) {
    if (quote.isBulkStudentRate) {
      return AdminPremiumCard(
        child: Row(
          children: [
            const Icon(Icons.trending_down_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You qualify for bulk pricing: ${SubscriptionPricing.formatInr(SubscriptionPricing.bulkStudentRate)} per student because you have more than ${SubscriptionPricing.bulkStudentThreshold} students.',
                style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = SubscriptionPricing.bulkStudentThreshold - quote.studentCount + 1;
    return AdminPremiumCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add $remaining more students to unlock bulk rate of '
              '${SubscriptionPricing.formatInr(SubscriptionPricing.bulkStudentRate)} per student.',
              style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatelessWidget {
  const _CheckoutSheet({required this.quote});

  final SubscriptionQuote quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.paddingOf(context).bottom + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm subscription',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'You are subscribing to the SmartUp School Management app for 30 days.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          AdminPremiumCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _line('Students', SubscriptionPricing.formatInr(quote.studentTotal)),
                const SizedBox(height: 8),
                _line('Teachers', SubscriptionPricing.formatInr(quote.teacherTotal)),
                const Divider(height: 22),
                _line('Total due today', SubscriptionPricing.formatInr(quote.monthlyTotal), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminPrimaryButton(
            label: 'Pay ${SubscriptionPricing.formatInr(quote.monthlyTotal)}',
            icon: Icons.lock_rounded,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: bold ? 16 : 13,
            color: bold ? AppColors.primary : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
