import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  ConsumerState<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  Map<String, dynamic>? _overview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final classes = await ref.read(dioProvider).get('/teacher/classes');
      final list = classes.data as List<dynamic>? ?? [];
      if (list.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final classId = list.first['id'];
      final res = await ref.read(dioProvider).get(
            '/teacher/reports/overview',
            queryParameters: {'classId': classId},
          );
      if (!mounted) return;
      setState(() {
        _overview = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          const TeacherPageHeader(
            title: 'Reports',
            subtitle: 'Performance & analytics',
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.teacherPrimary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          if (_overview != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TeacherStatCard(
                                    label: 'Students',
                                    value: '${_overview!['totalStudents']}',
                                    icon: Icons.groups_rounded,
                                    color: AppColors.teacherPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TeacherStatCard(
                                    label: 'Attendance',
                                    value: '${_overview!['averageAttendance']}%',
                                    icon: Icons.fact_check_outlined,
                                    color: AppColors.statGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TeacherStatCard(
                                    label: 'Avg marks',
                                    value: '${_overview!['classAverageMarks']}%',
                                    icon: Icons.grade_rounded,
                                    color: AppColors.statOrange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TeacherStatCard(
                                    label: 'Pass rate',
                                    value: '${_overview!['passPercentage']}%',
                                    icon: Icons.trending_up_rounded,
                                    color: AppColors.statPurple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                          const TeacherSectionTitle('Report types'),
                          Container(
                            decoration: teacherCardDecoration(),
                            child: Column(
                              children: [
                                _reportTile(Icons.calendar_month_rounded, 'Attendance report', 'Summary and trends'),
                                const Divider(height: 1, indent: 68),
                                _reportTile(Icons.assignment_rounded, 'Marks report', 'Subject-wise grades'),
                                const Divider(height: 1, indent: 68),
                                _reportTile(Icons.insights_rounded, 'Student performance', 'Detailed analysis'),
                                const Divider(height: 1, indent: 68),
                                _reportTile(Icons.task_alt_rounded, 'Assignment report', 'Submissions & scores'),
                              ],
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

  Widget _reportTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.teacherPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.teacherPrimary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
    );
  }
}
