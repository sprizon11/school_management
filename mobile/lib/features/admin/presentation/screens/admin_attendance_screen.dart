import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
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
      final res = await ref.read(dioProvider).get('/admin/attendance/overview');
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
    final today = _data?['today'] as Map<String, dynamic>? ?? {};
    final weekly = _data?['weekly'] as List<dynamic>? ?? [];
    final classes = _data?['classes'] as List<dynamic>? ?? [];

    return AdminSubPageScaffold(
      title: 'Attendance',
      subtitle: 'Track daily and class-wise attendance',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      AdminStatTile(
                        label: 'Present Today',
                        value: '${today['present'] ?? 0}',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF22A750),
                      ),
                      AdminStatTile(
                        label: 'Absent Today',
                        value: '${today['absent'] ?? 0}',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFFF5D5D),
                      ),
                      AdminStatTile(
                        label: 'On Leave',
                        value: '${today['leave'] ?? 0}',
                        icon: Icons.event_busy_rounded,
                        color: const Color(0xFFF5A623),
                      ),
                      AdminStatTile(
                        label: 'Attendance %',
                        value: '${today['percent'] ?? 0}%',
                        icon: Icons.percent_rounded,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdminPremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly Trend',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: weekly.isEmpty ? 5 : (weekly.length - 1).toDouble(),
                              minY: 0,
                              maxY: 100,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) =>
                                    const FlLine(color: Color(0xFFEEF1F6)),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    interval: 1,
                                    getTitlesWidget: (value, _) {
                                      if (value != value.roundToDouble()) {
                                        return const SizedBox.shrink();
                                      }
                                      final i = value.toInt();
                                      if (i < 0 || i >= weekly.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Text(
                                        '${weekly[i]['day']}',
                                        style: const TextStyle(fontSize: 11),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    weekly.length,
                                    (i) => FlSpot(
                                      i.toDouble(),
                                      (weekly[i]['percent'] as num).toDouble(),
                                    ),
                                  ),
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                  ),
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Class-wise Attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...classes.map((c) {
                    final m = c as Map<String, dynamic>;
                    return AdminListTilePremium(
                      title: '${m['name']}',
                      subtitle: '${m['studentCount']} students · ${m['marked']} marked',
                      trailing: '${m['percent']}%',
                      leadingIcon: Icons.class_rounded,
                      leadingColor: AppColors.primary,
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
