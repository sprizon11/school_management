import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
class AdminStudentDetailScreen extends ConsumerStatefulWidget {
  const AdminStudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<AdminStudentDetailScreen> createState() =>
      _AdminStudentDetailScreenState();
}

class _AdminStudentDetailScreenState
    extends ConsumerState<AdminStudentDetailScreen> {
  Map<String, dynamic>? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(dioProvider)
          .get('/admin/students/${widget.studentId}');
      setState(() {
        _student = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? 'Failed to load';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load student';
        _loading = false;
      });
    }
  }

  ImageProvider? _avatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64 = url.split(',').last;
      return MemoryImage(base64Decode(base64));
    }
    return NetworkImage(url);
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse('$value');
    if (dt == null) return '—';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _heroHeader(topPad)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _quickStats(),
                      const SizedBox(height: 16),
                      _section(
                        'Personal Information',
                        Icons.person_outline_rounded,
                        [
                          _row('Full Name', '${_student!['fullName']}'),
                          _row('Student ID', '${_student!['studentCode']}'),
                          _row('Gender', _genderLabel('${_student!['gender']}')),
                          _row('Date of Birth', _formatDate(_student!['dateOfBirth'])),
                          _row('Blood Group', '${_student!['bloodGroup'] ?? '—'}'),
                          _row('Email', '${_student!['email'] ?? '—'}'),
                          _row('Phone', '${_student!['phone'] ?? '—'}'),
                          _row('Address', '${_student!['address'] ?? '—'}'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Academic Details',
                        Icons.school_outlined,
                        [
                          _row('Class', '${_student!['grade']} ${_student!['section']}'),
                          _row('Class Name', '${_student!['className'] ?? '—'}'),
                          _row('Roll Number', '${_student!['rollNumber'] ?? '—'}'),
                          if (_student!['classTeacher'] != null)
                            _row(
                              'Class Teacher',
                              '${(_student!['classTeacher'] as Map)['name']}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Parent & Guardian',
                        Icons.family_restroom_rounded,
                        [
                          _row('Father', '${_student!['fatherName'] ?? '—'}'),
                          _row('Father Phone', '${_student!['fatherPhone'] ?? '—'}'),
                          _row('Father Occupation', '${_student!['fatherOccupation'] ?? '—'}'),
                          _row('Mother', '${_student!['motherName'] ?? '—'}'),
                          _row('Mother Phone', '${_student!['motherPhone'] ?? '—'}'),
                          _row('Mother Occupation', '${_student!['motherOccupation'] ?? '—'}'),
                          _row('Guardian Address', '${_student!['parentAddress'] ?? '—'}'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Emergency Contact',
                        Icons.emergency_outlined,
                        [
                          _row('Contact Name', '${_student!['emergencyContact'] ?? '—'}'),
                          _row('Emergency Phone', '${_student!['emergencyPhone'] ?? '—'}'),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader(double topPad) {
    final s = _student!;
    final isActive = '${s['status']}' == 'ACTIVE';
    final gender = '${s['gender']}';
    final avatarBg = gender == 'FEMALE'
        ? const Color(0xFFFCE7F3)
        : const Color(0xFFDBEAFE);

    return Container(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3FC9), Color(0xFF2368FF), Color(0xFF4388FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _roundBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
              const Spacer(),
              _roundBtn(Icons.refresh_rounded, _load),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 44,
            backgroundColor: avatarBg,
            backgroundImage: _avatarImage(s['avatarUrl'] as String?),
            child: s['avatarUrl'] == null
                ? Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: gender == 'FEMALE'
                        ? const Color(0xFFDB2777)
                        : const Color(0xFF2563EB),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '${s['fullName']}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${s['studentCode']}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF166534)
                    : const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 36,
          width: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _quickStats() {
    final s = _student!;
    final attendance = s['attendancePercent'];

    return Transform.translate(
      offset: const Offset(0, -20),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              Icons.class_rounded,
              'Class',
              '${s['grade']}${s['section']}',
              const Color(0xFF3B6FF5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              Icons.tag_rounded,
              'Roll No.',
              '${s['rollNumber'] ?? '—'}',
              const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              Icons.event_available_rounded,
              'Attendance',
              attendance != null ? '$attendance%' : '—',
              const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _genderLabel(String gender) {
    if (gender == 'MALE') return 'Male';
    if (gender == 'FEMALE') return 'Female';
    return gender;
  }
}
