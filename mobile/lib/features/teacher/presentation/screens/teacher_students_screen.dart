import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  String? _classId;
  List<dynamic> _students = [];
  Map<String, dynamic>? _classInfo;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await ref.read(dioProvider).get('/teacher/classes');
      final list = classes.data as List<dynamic>;
      if (list.isEmpty) return;
      final c9 = list.cast<Map<String, dynamic>>().firstWhere(
            (c) => c['grade'] == 9 && c['section'] == 'A',
            orElse: () => list.first as Map<String, dynamic>,
          );
      _classId = c9['id'] as String;
      final detail = await ref.read(dioProvider).get('/teacher/classes/$_classId');
      final roster = await ref.read(dioProvider).get('/teacher/classes/$_classId/students', queryParameters: {'limit': 20});
      setState(() {
        _classInfo = detail.data as Map<String, dynamic>;
        _students = (roster.data as Map)['items'] as List<dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Students', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('View and manage all students in this class', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        if (_classInfo != null)
          Card(
            color: AppColors.teacherPrimary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.teacherPrimary, borderRadius: BorderRadius.circular(8)),
                    child: Text('${_classInfo!['grade']}${_classInfo!['section']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Class ${_classInfo!['grade']}${_classInfo!['section']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_classInfo!['_count']?['students'] ?? _students.length} Students · ${_classInfo!['room'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        ..._students.map((s) {
          final st = s as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text(st['fullName'][0])),
              title: Text(st['fullName']),
              subtitle: Text(st['studentCode'] ?? ''),
              trailing: Chip(label: Text(st['gender'] ?? ''), padding: EdgeInsets.zero),
            ),
          );
        }),
      ],
    );
  }
}
