import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get('/teacher/dashboard/summary');
      setState(() => _data = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final teacher = _data?['teacher'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Good Morning, ${user?.fullName ?? 'Teacher'}! 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.teacherPrimary, Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacher?['fullName'] ?? user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text((teacher?['subjects'] as List?)?.join(', ') ?? 'Teacher', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Classes Today', '${_data?['classesToday'] ?? 0}'),
              _stat('Pending Grading', '${_data?['pendingGrading'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat('Attendance', '${_data?['attendanceMarkedPercent'] ?? 0}%'),
              _stat('Leave Req.', '${_data?['leaveRequestsPending'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(child: ListTile(leading: const Icon(Icons.schedule, color: AppColors.teacherPrimary), title: const Text('08:00 - Mathematics'), subtitle: const Text('Room 203'))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quick('Mark Attendance', Icons.check_circle, AppColors.teacherPrimary),
              _quick('Upload Marks', Icons.upload, AppColors.statGreen),
              _quick('Homework', Icons.book, AppColors.statOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _quick(String label, IconData icon, Color c) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Icon(icon, color: c), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600))]),
    );
  }
}
