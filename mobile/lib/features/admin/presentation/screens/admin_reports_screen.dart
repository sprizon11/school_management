import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
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
      final res = await ref.read(dioProvider).get('/admin/reports/overview');
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _data?['students'] as Map<String, dynamic>? ?? {};
    final teachers = _data?['teachers'] as Map<String, dynamic>? ?? {};
    final classes = _data?['classes'] as Map<String, dynamic>? ?? {};
    final fees = _data?['fees'] as Map<String, dynamic>? ?? {};
    final activities = _data?['activities'] as List<dynamic>? ?? [];

    return AdminSubPageScaffold(
      title: 'Reports',
      subtitle: 'School analytics and activity log',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  EntranceFade(
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        AdminStatTile(
                          label: 'Total Students',
                          value: '${students['total'] ?? 0}',
                          icon: Icons.groups_rounded,
                          color: const Color(0xFF5B6CFF),
                        ),
                        AdminStatTile(
                          label: 'Total Teachers',
                          value: '${teachers['total'] ?? 0}',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF3DD16E),
                        ),
                        AdminStatTile(
                          label: 'Total Classes',
                          value: '${classes['totalClasses'] ?? 0}',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFFF5A623),
                        ),
                        AdminStatTile(
                          label: 'Fee Collected',
                          value: '₹${_compact(fees['total'])}',
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFFFF5D6E),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceFade(
                    delay: const Duration(milliseconds: 70),
                    child: AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gender Distribution',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _bar(
                            'Boys',
                            students['boysPercent'] ?? 0,
                            const Color(0xFF3B9EFF),
                          ),
                          const SizedBox(height: 10),
                          _bar(
                            'Girls',
                            students['girlsPercent'] ?? 0,
                            const Color(0xFFFF6B9D),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (activities.isEmpty)
                    const AdminPremiumCard(
                      child: Text(
                        'No recent activity.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    for (var i = 0; i < activities.length; i++)
                      EntranceFadeItem(
                        index: i,
                        child: Builder(
                          builder: (_) {
                            final m = activities[i] as Map<String, dynamic>;
                            final date = DateTime.tryParse('${m['createdAt']}');
                            return AdminListTilePremium(
                              title: '${m['action']}',
                              subtitle: '${m['actorName']}',
                              trailing: date != null
                                  ? DateFormat('dd MMM').format(date.toLocal())
                                  : null,
                              leadingIcon: Icons.history_rounded,
                              leadingColor: AppColors.primary,
                            );
                          },
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _bar(String label, dynamic percent, Color color) {
    final p = (percent as num?)?.toDouble() ?? 0;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFEEF1F6),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${p.round()}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _compact(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
