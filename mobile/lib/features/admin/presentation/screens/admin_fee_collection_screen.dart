import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/motion.dart';

class AdminFeeCollectionScreen extends ConsumerStatefulWidget {
  const AdminFeeCollectionScreen({super.key});

  @override
  ConsumerState<AdminFeeCollectionScreen> createState() =>
      _AdminFeeCollectionScreenState();
}

class _AdminFeeCollectionScreenState
    extends ConsumerState<AdminFeeCollectionScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF6D5DE8);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  Map<String, dynamic>? _data;
  bool _loading = true;
  int _tab = 0; // 0 Overview, 1 Fee Structures, 2 Transactions

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/fees/overview');
      if (!mounted) return;
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _summary =>
      _data?['summary'] as Map<String, dynamic>? ?? {};
  List<dynamic> get _payments =>
      _data?['recentPayments'] as List<dynamic>? ?? [];

  int get _collected => _toInt(_summary['collected']);
  int get _pending => _toInt(_summary['pending']);
  int get _overdue => 0; // not tracked yet
  int get _total => _collected + _pending + _overdue;
  int get _collectionRate =>
      _total > 0 ? (_collected / _total * 100).round() : 0;
  int _pctOf(int part) => _total > 0 ? (part / _total * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _purple),
                    )
                  : RefreshIndicator(
                      color: _purple,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                        children: [
                          EntranceFade(child: _statsRow()),
                          const SizedBox(height: 14),
                          EntranceFade(
                            delay: const Duration(milliseconds: 60),
                            child: _tabs(),
                          ),
                          const SizedBox(height: 16),
                          if (_tab == 0) ..._overviewTab(),
                          if (_tab == 1) _feeStructuresTab(),
                          if (_tab == 2) _transactionsTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          _backButton(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fees',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage fee collection and payments',
                  style: TextStyle(
                    fontSize: 12,
                    color: _ink.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _gradientButton(
            'Add Fee',
            Icons.add_rounded,
            () => _snack('Add fee — coming soon'),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _ink,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _gradientButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C6FF2), Color(0xFF6355E0)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
  Widget _statsRow() {
    return SizedBox(
      height: 132,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _statCard(
            Icons.account_balance_wallet_rounded,
            _purple,
            _fmt(_collected),
            'Total Collected',
            'This Month',
            up: true,
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.pending_actions_rounded,
            _green,
            _fmt(_pending),
            'Pending Amount',
            '${_pctOf(_pending)}% of total',
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.warning_amber_rounded,
            _red,
            _fmt(_overdue),
            'Overdue Amount',
            '${_pctOf(_overdue)}% of total',
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.trending_up_rounded,
            const Color(0xFF3B82F6),
            '$_collectionRate%',
            'Collection Rate',
            'This Month',
            up: true,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    Color color,
    String value,
    String label,
    String sub, {
    bool up = false,
  }) {
    return Container(
      width: 156,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _ink.withValues(alpha: 0.45),
                ),
              ),
              if (up) ...[
                const SizedBox(width: 3),
                Icon(Icons.trending_up_rounded, size: 12, color: color),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _tabs() {
    final labels = ['Overview', 'Fee Structures', 'Transactions'];
    final icons = [
      Icons.pie_chart_rounded,
      Icons.description_rounded,
      Icons.swap_horiz_rounded,
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? _purple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        size: 15,
                        color: _tab == i
                            ? _purple
                            : _ink.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _tab == i
                                ? _purple
                                : _ink.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
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
  List<Widget> _overviewTab() {
    return [
      EntranceFade(
        delay: const Duration(milliseconds: 110),
        child: _filterPills(),
      ),
      const SizedBox(height: 16),
      EntranceFade(
        delay: const Duration(milliseconds: 160),
        child: _collectionCard(),
      ),
      const SizedBox(height: 22),
      _sectionHeader(
        'Recent Fee Payments',
        trailing: 'View All',
        onTap: () => setState(() => _tab = 2),
      ),
      const SizedBox(height: 10),
      _paymentsList(_payments.take(5).toList()),
      const SizedBox(height: 22),
      _sectionHeader('Fee Due Summary'),
      const SizedBox(height: 10),
      EntranceFade(
        delay: const Duration(milliseconds: 210),
        child: _dueSummary(),
      ),
    ];
  }

  Widget _filterPills() {
    return Row(
      children: [
        Expanded(
          child: _dropPill(Icons.school_rounded, 'Class', 'All Classes'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropPill(
            Icons.calendar_today_rounded,
            'Month',
            _currentMonth(),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.tune_rounded, color: _purple, size: 22),
        ),
      ],
    );
  }

  Widget _dropPill(IconData icon, String label, String value) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _purple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: _ink.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: _ink.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _collectionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Fee Collection Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Text(
                'This Month',
                style: TextStyle(
                  fontSize: 12,
                  color: _ink.withValues(alpha: 0.45),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _ink.withValues(alpha: 0.45),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: (_collectionRate / 100).clamp(0.0, 1.0),
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFEDEFF4),
                        valueColor: const AlwaysStoppedAnimation(_purple),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_collectionRate%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Collected',
                          style: TextStyle(
                            fontSize: 11,
                            color: _ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _legendRow(_purple, 'Collected Amount', _fmt(_collected)),
                    const SizedBox(height: 12),
                    _legendRow(_amber, 'Pending Amount', _fmt(_pending)),
                    const SizedBox(height: 12),
                    _legendRow(_red, 'Overdue Amount', _fmt(_overdue)),
                    const SizedBox(height: 12),
                    _legendRow(
                      const Color(0xFFCBD0DC),
                      'Total Amount',
                      _fmt(_total),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, String amount) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: _ink.withValues(alpha: 0.6)),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _paymentsList(List<dynamic> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: const Text(
          'No fee payments recorded yet.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            _paymentRow(
              list[i] as Map<String, dynamic>,
              first: i == 0,
              last: i == list.length - 1,
            ),
            if (i < list.length - 1)
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

  Widget _paymentRow(
    Map<String, dynamic> m, {
    required bool first,
    required bool last,
  }) {
    final name = '${m['studentName'] ?? 'Student'}';
    final date = DateTime.tryParse('${m['paidAt']}');
    final dateLabel = date != null
        ? DateFormat('d MMM yyyy').format(date.toLocal())
        : '';
    final cls = '${m['className'] ?? ''}';
    final grade = '${m['grade'] ?? ''}';
    final sub = cls.isNotEmpty
        ? 'Class $grade${cls.isNotEmpty ? ' · $cls' : ''}'
        : '${m['method'] ?? 'Online Payment'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: _green, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(m['amount']),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _ink.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _statusPill('Paid', _green),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: _ink.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _dueSummary() {
    // Aging buckets are not tracked in the API yet — shown as an at-a-glance
    // frame; the pending total is surfaced so the section isn't empty.
    final buckets = <({String label, int amount, int students, Color color})>[
      (label: '0 - 30 Days', amount: _pending, students: 0, color: _green),
      (label: '31 - 60 Days', amount: 0, students: 0, color: _amber),
      (label: '61 - 90 Days', amount: 0, students: 0, color: _red),
      (label: '90+ Days', amount: 0, students: 0, color: _purple),
    ];
    return Row(
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _dueBucket(buckets[i])),
        ],
      ],
    );
  }

  Widget _dueBucket(({String label, int amount, int students, Color color}) b) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: b.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            b.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: _ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _fmt(b.amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: b.color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${b.students} Students',
            style: TextStyle(
              fontSize: 9.5,
              color: _ink.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeStructuresTab() {
    return _placeholderTab(
      Icons.description_outlined,
      'Fee Structures',
      'Create and manage fee plans per class and term. Coming soon.',
    );
  }

  Widget _transactionsTab() {
    return Column(
      children: [
        _sectionHeader('All Transactions'),
        const SizedBox(height: 10),
        _paymentsList(_payments),
      ],
    );
  }

  Widget _placeholderTab(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 42, color: _purple.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _ink.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing, VoidCallback? onTap}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
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
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _purple,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _purple,
                ),
              ],
            ),
          ),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: _purple.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _currentMonth() => DateFormat('MMMM yyyy').format(DateTime.now());

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
}
