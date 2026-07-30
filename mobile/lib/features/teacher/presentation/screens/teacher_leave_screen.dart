import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Leave requests from parents of the teacher's classes — approve or decline
/// (GET /teacher/leave, PATCH /teacher/leave/:id).
class TeacherLeaveScreen extends ConsumerStatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  ConsumerState<TeacherLeaveScreen> createState() =>
      _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends ConsumerState<TeacherLeaveScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = AppColors.teacherPrimary;
  static const _green = AppColors.statGreen;
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  List<dynamic> _items = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _items.isEmpty);
    try {
      final res = await ref.read(dioProvider).get('/teacher/leave');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, bool approve) async {
    setState(() => _busy.add(id));
    try {
      await ref.read(dioProvider).patch(
        '/teacher/leave/$id',
        data: {'approve': approve},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Leave approved' : 'Leave declined'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: approve ? _green : _red,
        ),
      );
      await _load();
    } on DioException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the request')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Leave Requests', 'From your classes'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : RefreshIndicator(
              color: _purple,
              onRefresh: _load,
              child: _items.isEmpty
                  ? _empty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _card(Map<String, dynamic>.from(_items[i] as Map)),
                    ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> l) {
    final status = '${l['status']}';
    final pending = status == 'PENDING';
    final id = '${l['id']}';
    final from = DateTime.tryParse('${l['fromDate'] ?? ''}');
    final to = DateTime.tryParse('${l['toDate'] ?? ''}');
    final range = from == null
        ? ''
        : to == null || _sameDay(from, to)
            ? DateFormat('d MMM yyyy').format(from.toLocal())
            : '${DateFormat('d MMM').format(from.toLocal())} – ${DateFormat('d MMM yyyy').format(to.toLocal())}';
    final busy = _busy.contains(id);

    final statusColor = status == 'APPROVED'
        ? _green
        : status == 'REJECTED'
            ? _red
            : _amber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: teacherCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: _purple,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l['studentName'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      '${l['className'] ?? ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _ink.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!pending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'APPROVED' ? 'Approved' : 'Declined',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.date_range_rounded, size: 14, color: _amber),
              const SizedBox(width: 6),
              Text(
                range,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l['reason'] ?? ''}',
            style: TextStyle(
              fontSize: 12.5,
              color: _ink.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          if (pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _review(id, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: BorderSide(color: _red.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _review(id, true),
                    icon: busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      Icon(
        Icons.event_available_rounded,
        size: 46,
        color: _purple.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No leave requests',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink.withValues(alpha: 0.6),
          ),
        ),
      ),
    ],
  );
}
