import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/child_card.dart';

class ParentResultsScreen extends ConsumerStatefulWidget {
  const ParentResultsScreen({super.key});

  @override
  ConsumerState<ParentResultsScreen> createState() => _ParentResultsScreenState();
}

class _ParentResultsScreenState extends ConsumerState<ParentResultsScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _marks = [];
  Map<String, dynamic>? _remarks;

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
      final q = {'studentId': sid};
      final results = await Future.wait([
        dio.get('/parent/results/summary', queryParameters: q),
        dio.get('/parent/results/marks', queryParameters: q),
        dio.get('/parent/results/remarks', queryParameters: q),
      ]);
      setState(() {
        _summary = results[0].data as Map<String, dynamic>;
        _marks = results[1].data as List<dynamic>;
        _remarks = results[2].data as Map<String, dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Results', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("View your child's academic results", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        const ChildCard(name: 'Aryan Kumar', classLine: 'Class 9A • Roll No. 15'),
        if (_summary != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('Grade', _summary!['overallGrade'] as String? ?? 'A'),
              _metric('Score', '${_summary!['overallPercent']}%'),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Text('Subject Wise Marks', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._marks.map((m) {
          final row = m as Map<String, dynamic>;
          final sub = row['subject'] as Map<String, dynamic>;
          final pct = (row['marks'] as int) / (row['maxMarks'] as int);
          return Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              title: Text(sub['name'] as String),
              subtitle: LinearProgressIndicator(value: pct, color: AppColors.statGreen),
              trailing: Text('${row['marks']}/${row['maxMarks']} · ${row['grade']}'),
            ),
          );
        }),
        if (_remarks != null) ...[
          const SizedBox(height: 16),
          const Text('Teacher Remarks', style: TextStyle(fontWeight: FontWeight.bold)),
          Card(
            color: AppColors.parentPrimary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${_remarks!['text']}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text('- ${_remarks!['teacherName']} (${_remarks!['role']})'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label),
          ]),
        ),
      ),
    );
  }
}
