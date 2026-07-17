import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminExaminationsScreen extends ConsumerStatefulWidget {
  const AdminExaminationsScreen({super.key});

  @override
  ConsumerState<AdminExaminationsScreen> createState() =>
      _AdminExaminationsScreenState();
}

class _AdminExaminationsScreenState
    extends ConsumerState<AdminExaminationsScreen> {
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
      final res = await ref
          .read(dioProvider)
          .get('/admin/examinations/overview');
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
    final subjects = _data?['subjects'] as List<dynamic>? ?? [];
    final results = _data?['recentResults'] as List<dynamic>? ?? [];
    final terms = _data?['terms'] as List<dynamic>? ?? [];

    return AdminSubPageScaffold(
      title: 'Examinations',
      subtitle: 'View results and subject performance',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (terms.isNotEmpty)
                    AdminPremiumCard(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: terms
                            .take(4)
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$t',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Subject Averages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...subjects.map((s) {
                    final m = s as Map<String, dynamic>;
                    final avg = m['average'] as int? ?? 0;
                    return AdminPremiumCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${m['subject']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: avg / 100,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFEEF1F6),
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$avg%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Text(
                    'Recent Results',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...results.map((r) {
                    final m = r as Map<String, dynamic>;
                    return AdminListTilePremium(
                      title: '${m['studentName']}',
                      subtitle:
                          '${m['subject']} · ${m['className']} · ${m['termLabel']}',
                      trailing:
                          '${m['marks']}/${m['maxMarks']} (${m['grade']})',
                      leadingIcon: Icons.grade_rounded,
                      leadingColor: const Color(0xFF6B5CE7),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
