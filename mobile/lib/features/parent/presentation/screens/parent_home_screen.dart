import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/child_card.dart';

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _announcements = [];
  List<dynamic> _performance = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final studentId = ref.read(selectedStudentIdProvider);
    try {
      final dio = ref.read(dioProvider);
      if (studentId == null) {
        final children = await dio.get('/parent/children');
        final list = children.data as List<dynamic>;
        if (list.isNotEmpty) {
          ref.read(selectedStudentIdProvider.notifier).state = list.first['id'] as String;
        }
      }
      final sid = ref.read(selectedStudentIdProvider);
      final results = await Future.wait([
        dio.get('/parent/dashboard/summary', queryParameters: {if (sid != null) 'studentId': sid}),
        dio.get('/parent/announcements'),
        dio.get('/parent/performance/by-subject', queryParameters: {if (sid != null) 'studentId': sid}),
      ]);
      setState(() {
        _summary = results[0].data as Map<String, dynamic>;
        _announcements = results[1].data as List<dynamic>;
        _performance = results[2].data as List<dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final student = _summary?['student'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Good Morning, ${user?.fullName ?? 'Parent'}! 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Welcome back! Here's what's happening with your child."),
          const SizedBox(height: 12),
          if (student != null)
            ChildCard(
              name: student['fullName'] as String,
              classLine: student['className'] as String? ?? '',
              onSwitch: () {},
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('Attendance', '${_summary?['attendancePercent'] ?? 0}%', AppColors.parentPrimary),
              _stat('Average', '${_summary?['averageGrade'] ?? '-'}', AppColors.statGreen),
            ],
          ),
          Row(
            children: [
              _stat('Assignments', '${_summary?['assignmentsSubmitted']}/${_summary?['assignmentsTotal']}', AppColors.statOrange),
              _stat('Leave', '${_summary?['leaveRequestsPending'] ?? 0}', AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Quick Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _quick(Icons.calendar_month, 'Attendance', AppColors.parentPrimary),
              _quick(Icons.grade, 'Results', AppColors.statGreen),
              _quick(Icons.book, 'Homework', AppColors.statOrange),
              _quick(Icons.wallet, 'Fees', AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Latest Announcements', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._announcements.take(3).map((a) {
            final m = a as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: const Icon(Icons.campaign, color: AppColors.parentPrimary),
                title: Text(m['title'] as String),
                subtitle: Text(m['body'] as String? ?? ''),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text('Subject Wise Performance', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._performance.map((p) {
            final m = p as Map<String, dynamic>;
            final pct = (m['percent'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['subject'] as String),
                  LinearProgressIndicator(value: pct / 100, color: AppColors.parentPrimary, backgroundColor: Colors.grey.shade200),
                  Text('$pct%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color c) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _quick(IconData icon, String label, Color c) {
    return SizedBox(
      width: 72,
      child: Column(children: [
        CircleAvatar(backgroundColor: c.withValues(alpha: 0.15), child: Icon(icon, color: c, size: 22)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
      ]),
    );
  }
}
