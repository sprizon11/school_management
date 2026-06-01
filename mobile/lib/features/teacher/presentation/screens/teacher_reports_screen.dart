import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

class TeacherReportsScreen extends ConsumerStatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  ConsumerState<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends ConsumerState<TeacherReportsScreen> {
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final classes = await ref.read(dioProvider).get('/teacher/classes');
      final list = classes.data as List<dynamic>;
      if (list.isEmpty) return;
      final classId = list.first['id'];
      final res = await ref.read(dioProvider).get('/teacher/reports/overview', queryParameters: {'classId': classId});
      setState(() => _overview = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.teacherPrimary)),
        const Text('View and analyze performance reports', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        if (_overview != null) ...[
          Row(children: [
            Expanded(child: _metric('Students', '${_overview!['totalStudents']}')),
            Expanded(child: _metric('Attendance', '${_overview!['averageAttendance']}%')),
          ]),
          Row(children: [
            Expanded(child: _metric('Avg Marks', '${_overview!['classAverageMarks']}%')),
            Expanded(child: _metric('Pass %', '${_overview!['passPercentage']}%')),
          ]),
        ],
        const SizedBox(height: 16),
        _reportRow('Attendance Report', 'View attendance summary and trends'),
        _reportRow('Marks Report', 'View subject-wise marks and grades'),
        _reportRow('Student Performance', 'Detailed performance analysis'),
        _reportRow('Assignment Report', 'Submission and scores'),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _reportRow(String title, String sub) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
