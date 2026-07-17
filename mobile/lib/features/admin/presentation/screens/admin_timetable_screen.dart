import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminTimetableScreen extends ConsumerStatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  ConsumerState<AdminTimetableScreen> createState() =>
      _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends ConsumerState<AdminTimetableScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/timetable');
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
    final entries = _data?['entries'] as List<dynamic>? ?? [];
    final days = _data?['days'] as List<dynamic>? ?? [];
    final selectedEntry = entries.isEmpty
        ? null
        : entries[_selected] as Map<String, dynamic>;
    final schedule = selectedEntry?['schedule'] as List<dynamic>? ?? [];

    return AdminSubPageScaffold(
      title: 'Time Table',
      subtitle: 'Class schedules and periods',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final e = entries[i] as Map<String, dynamic>;
                        final active = i == _selected;
                        return ChoiceChip(
                          label: Text('${e['className']}'),
                          selected: active,
                          onSelected: (_) => setState(() => _selected = i),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          labelStyle: TextStyle(
                            color: active
                                ? AppColors.primary
                                : const Color(0xFF4B5563),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (selectedEntry != null)
                          AdminPremiumCard(
                            child: Row(
                              children: [
                                Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${selectedEntry['className']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${selectedEntry['teacher']} · ${selectedEntry['room']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        ...schedule.map((slot) {
                          final m = slot as Map<String, dynamic>;
                          return AdminListTilePremium(
                            title: '${m['day']} · ${m['period']}',
                            subtitle: '${m['subject']}',
                            leadingIcon: Icons.access_time_rounded,
                            leadingColor: const Color(0xFF3B9EFF),
                          );
                        }),
                        if (entries.isEmpty)
                          const AdminPremiumCard(
                            child: Text(
                              'No timetable entries available.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        if (days.isNotEmpty && entries.isEmpty)
                          const SizedBox(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
