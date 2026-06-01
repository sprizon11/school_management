import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/child_card.dart';

class ParentAttendanceScreen extends ConsumerStatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  ConsumerState<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends ConsumerState<ParentAttendanceScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sid = ref.read(selectedStudentIdProvider);
    if (sid == null) return;
    try {
      final dio = ref.read(dioProvider);
      final summary = await dio.get('/parent/attendance/summary', queryParameters: {'studentId': sid});
      final recent = await dio.get('/parent/attendance/recent', queryParameters: {'studentId': sid});
      setState(() {
        _summary = summary.data as Map<String, dynamic>;
        _recent = recent.data as List<dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("View your child's attendance", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        const ChildCard(name: 'Aryan Kumar', classLine: 'Class 9A • Roll No. 15'),
        const SizedBox(height: 12),
        if (_summary != null)
          Row(
            children: [
              _box('Present', '${_summary!['presentDays']}', AppColors.statGreen),
              _box('Absent', '${_summary!['absentDays']}', AppColors.absentRed),
              _box('Leave', '${_summary!['leaveDays']}', AppColors.leaveOrange),
              _box('Total', '${_summary!['totalPercent']}%', AppColors.parentPrimary),
            ],
          ),
        const SizedBox(height: 16),
        const Text('Recent Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._recent.map((r) {
          final m = r as Map<String, dynamic>;
          final present = m['status'] == 'PRESENT';
          return ListTile(
            leading: Icon(present ? Icons.check_circle : Icons.cancel, color: present ? Colors.green : Colors.red),
            title: Text(m['date'].toString().split('T').first),
            trailing: Chip(label: Text(m['status'] as String, style: const TextStyle(fontSize: 10))),
          );
        }),
      ],
    );
  }

  Widget _box(String label, String value, Color c) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Icon(Icons.calendar_today, color: c, size: 20),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}
