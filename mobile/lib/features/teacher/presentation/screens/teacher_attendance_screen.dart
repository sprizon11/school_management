import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Attendance sheet for one class on one day.
///
/// Everyone starts PRESENT — the teacher only ticks the students who are
/// missing, so a full class of 40 with 2 absentees is two taps, not forty.
/// Saves via POST /teacher/attendance, which records the untouched students
/// as present server-side.
class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _alreadyMarked = false;

  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _students = [];

  /// Only the exceptions are tracked; anyone not in these sets is present.
  final Set<String> _absent = {};
  final Set<String> _leave = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateParam =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Today';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${_date.day} ${months[_date.month - 1]} ${_date.year}';
  }

  int get _presentCount => _students.length - _absent.length - _leave.length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(dioProvider)
          .get(
            '/teacher/attendance',
            queryParameters: {'classId': widget.classId, 'date': _dateParam},
          );
      final data = Map<String, dynamic>.from(res.data as Map);
      final students = (data['students'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _alreadyMarked = data['alreadyMarked'] == true;
        _absent
          ..clear()
          ..addAll(
            students
                .where((s) => s['status'] == 'ABSENT')
                .map((s) => '${s['id']}'),
          );
        _leave
          ..clear()
          ..addAll(
            students
                .where((s) => s['status'] == 'LEAVE')
                .map((s) => '${s['id']}'),
          );
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.response?.data?['message']?.toString() ??
            'Could not load the class list. Pull to retry.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the class list. Pull to retry.';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.teacherPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  void _toggleAbsent(String id) {
    setState(() {
      _leave.remove(id);
      if (!_absent.remove(id)) _absent.add(id);
    });
  }

  void _toggleLeave(String id) {
    setState(() {
      _absent.remove(id);
      if (!_leave.remove(id)) _leave.add(id);
    });
  }

  void _markAllPresent() {
    setState(() {
      _absent.clear();
      _leave.clear();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/teacher/attendance',
            data: {
              'classId': widget.classId,
              'date': _dateParam,
              'absentStudentIds': _absent.toList(),
              'leaveStudentIds': _leave.toList(),
            },
          );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(res.data as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance saved — ${data['present']} present, '
            '${data['absent']} absent${(data['leave'] ?? 0) == 0 ? '' : ', ${data['leave']} on leave'}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.teacherPrimary,
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ??
            'Could not save attendance';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not save attendance';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Attendance', widget.classLabel),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary),
            )
          : Column(
              children: [
                _dateBar(),
                _summaryBar(),
                if (_error != null) _errorBanner(),
                Expanded(
                  child: _students.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.teacherPrimary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _students.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _studentRow(_students[i]),
                          ),
                        ),
                ),
                if (_students.isNotEmpty) _saveBar(),
              ],
            ),
    );
  }

  Widget _dateBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 17,
                      color: AppColors.teacherPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _dateLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const Spacer(),
                    if (_alreadyMarked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Already marked',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.textMuted,
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

  Widget _summaryBar() {
    final hasExceptions = _absent.isNotEmpty || _leave.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _countPill('$_presentCount present', const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _countPill('${_absent.length} absent', const Color(0xFFEF4444)),
          if (_leave.isNotEmpty) ...[
            const SizedBox(width: 8),
            _countPill('${_leave.length} leave', const Color(0xFFF59E0B)),
          ],
          const Spacer(),
          if (hasExceptions)
            TextButton(
              onPressed: _markAllPresent,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teacherPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _countPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> s) {
    final id = '${s['id']}';
    final isAbsent = _absent.contains(id);
    final isLeave = _leave.contains(id);
    final name = '${s['fullName'] ?? ''}';
    final roll = s['rollNumber'];

    final accent = isAbsent
        ? const Color(0xFFEF4444)
        : isLeave
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _toggleAbsent(id),
        onLongPress: () => _toggleLeave(id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAbsent || isLeave
                  ? accent.withValues(alpha: 0.5)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  roll == null ? '–' : '$roll',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAbsent
                          ? 'Absent'
                          : isLeave
                              ? 'On leave'
                              : 'Present',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLeave)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _toggleLeave(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Leave',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ),
                ),
              Checkbox(
                value: isAbsent,
                onChanged: (_) => _toggleAbsent(id),
                activeColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_2_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'No active students in this class yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tap a student to mark absent · long-press for leave',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          teacherPrimaryButton(
            label: _alreadyMarked ? 'Update attendance' : 'Save attendance',
            loading: _saving,
            onTap: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
