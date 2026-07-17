import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_edit_student_screen.dart';

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

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        page: AdminEditStudentScreen(studentId: widget.studentId),
      ),
    );
    if (updated == true) _load();
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
                SliverToBoxAdapter(child: _profileCard(topPad)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _quickStats(),
                      const SizedBox(height: 12),
                      _section(
                        'Personal Information',
                        Icons.person_outline_rounded,
                        [
                          _row('Full Name', '${_student!['fullName']}'),
                          _row('Student ID', '${_student!['studentCode']}'),
                          _row(
                            'Gender',
                            _genderLabel('${_student!['gender']}'),
                          ),
                          _row(
                            'Date of Birth',
                            _formatDate(_student!['dateOfBirth']),
                          ),
                          _row(
                            'Blood Group',
                            '${_student!['bloodGroup'] ?? '—'}',
                          ),
                          _row('Email', '${_student!['email'] ?? '—'}'),
                          _row('Phone', '${_student!['phone'] ?? '—'}'),
                          _row('Address', '${_student!['address'] ?? '—'}'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section('Academic Details', Icons.school_outlined, [
                        _row(
                          'Class',
                          '${_student!['grade']} ${_student!['section']}',
                        ),
                        _row('Class Name', '${_student!['className'] ?? '—'}'),
                        _row(
                          'Roll Number',
                          '${_student!['rollNumber'] ?? '—'}',
                        ),
                        if (_student!['classTeacher'] != null)
                          _row(
                            'Class Teacher',
                            '${(_student!['classTeacher'] as Map)['name']}',
                          ),
                      ]),
                      const SizedBox(height: 14),
                      _section(
                        'Parent & Guardian',
                        Icons.family_restroom_rounded,
                        [
                          _row('Father', '${_student!['fatherName'] ?? '—'}'),
                          _row(
                            'Father Phone',
                            '${_student!['fatherPhone'] ?? '—'}',
                          ),
                          _row(
                            'Father Occupation',
                            '${_student!['fatherOccupation'] ?? '—'}',
                          ),
                          _row('Mother', '${_student!['motherName'] ?? '—'}'),
                          _row(
                            'Mother Phone',
                            '${_student!['motherPhone'] ?? '—'}',
                          ),
                          _row(
                            'Mother Occupation',
                            '${_student!['motherOccupation'] ?? '—'}',
                          ),
                          _row(
                            'Guardian Address',
                            '${_student!['parentAddress'] ?? '—'}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section('Emergency Contact', Icons.emergency_outlined, [
                        _row(
                          'Contact Name',
                          '${_student!['emergencyContact'] ?? '—'}',
                        ),
                        _row(
                          'Emergency Phone',
                          '${_student!['emergencyPhone'] ?? '—'}',
                        ),
                      ]),
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

  Widget _profileCard(double topPad) {
    final s = _student!;
    final isActive = '${s['status']}' == 'ACTIVE';
    final gender = '${s['gender']}';
    final avatarBg = gender == 'FEMALE'
        ? const Color(0xFFFCE7F3)
        : const Color(0xFFDBEAFE);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF93C5FD)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: avatarBg,
                      backgroundImage: _avatarImage(s['avatarUrl'] as String?),
                      child: s['avatarUrl'] == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 34,
                              color: gender == 'FEMALE'
                                  ? const Color(0xFFDB2777)
                                  : const Color(0xFF2563EB),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['fullName']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s['studentCode']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(
                              '${s['grade']}${s['section']}',
                              const Color(0xFFEEF4FF),
                              AppColors.primary,
                            ),
                            _chip(
                              'Roll ${s['rollNumber'] ?? '—'}',
                              const Color(0xFFE8F8EE),
                              const Color(0xFF16A34A),
                            ),
                            _chip(
                              isActive ? 'Active' : 'Inactive',
                              isActive
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFFFEDD5),
                              isActive
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF9A3412),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEEF4FF),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _quickStats() {
    final s = _student!;
    final attendance = s['attendancePercent'];

    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.class_rounded,
            'Class',
            '${s['grade']}${s['section']}',
            const Color(0xFF3B6FF5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _statTile(
            Icons.tag_rounded,
            'Roll No.',
            '${s['rollNumber'] ?? '—'}',
            const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _statTile(
            Icons.event_available_rounded,
            'Attendance',
            attendance != null ? '$attendance%' : '—',
            const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 2),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
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
