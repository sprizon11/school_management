import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_class_detail_screen.dart';

class AdminTeacherDetailScreen extends ConsumerStatefulWidget {
  const AdminTeacherDetailScreen({super.key, required this.teacherId});

  final String teacherId;

  @override
  ConsumerState<AdminTeacherDetailScreen> createState() =>
      _AdminTeacherDetailScreenState();
}

class _AdminTeacherDetailScreenState
    extends ConsumerState<AdminTeacherDetailScreen> {
  Map<String, dynamic>? _teacher;
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
          .get('/admin/teachers/${widget.teacherId}');
      setState(() {
        _teacher = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? 'Failed to load';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load teacher';
        _loading = false;
      });
    }
  }

  ImageProvider? _avatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse('$value');
    if (dt == null) return '—';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  void _openClass(String classId) {
    openSmoothPage(context, AdminClassDetailScreen(classId: classId));
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
                          _row('Full Name', '${_teacher!['fullName']}'),
                          _row('Employee ID', '${_teacher!['employeeCode']}'),
                          _row(
                            'Gender',
                            _genderLabel('${_teacher!['gender']}'),
                          ),
                          _row('Email', '${_teacher!['email'] ?? '—'}'),
                          _row('Phone', '${_teacher!['phone'] ?? '—'}'),
                          _row(
                            'Joined',
                            _formatDate(_teacher!['createdAt']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Professional Details',
                        Icons.work_outline_rounded,
                        [
                          _row('Department', '${_teacher!['department']}'),
                          _row(
                            'Subjects',
                            _subjectsLabel(_teacher!['subjects']),
                          ),
                          _row('Status', 'Active'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _assignedClasses(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  String _subjectsLabel(dynamic subjects) {
    if (subjects is List && subjects.isNotEmpty) {
      return subjects.map((s) => '$s').join(', ');
    }
    return '—';
  }

  Widget _assignedClasses() {
    final classes = _teacher!['classes'] as List<dynamic>? ?? [];
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
                  child: const Icon(
                    Icons.class_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Assigned Classes (${classes.length})',
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
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No classes assigned yet',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            )
          else
            ...classes.map((c) {
              final cls = c as Map<String, dynamic>;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openClass('${cls['id']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${cls['grade']}${cls['section']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cls['name']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                '${cls['category'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
    final t = _teacher!;
    final gender = '${t['gender']}';
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
                  colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFC4B5FD)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: avatarBg,
                      backgroundImage: _avatarImage(t['avatarUrl'] as String?),
                      child: t['avatarUrl'] == null
                          ? Icon(
                              gender == 'FEMALE'
                                  ? Icons.woman_rounded
                                  : Icons.man_rounded,
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
                          '${t['fullName']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t['employeeCode']}',
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
                              '${t['department']}',
                              const Color(0xFFF3E8FF),
                              const Color(0xFF7C3AED),
                            ),
                            _chip(
                              _genderLabel(gender),
                              gender == 'FEMALE'
                                  ? const Color(0xFFFCE8F1)
                                  : const Color(0xFFE8F8EE),
                              gender == 'FEMALE'
                                  ? const Color(0xFFDB2777)
                                  : const Color(0xFF16A34A),
                            ),
                            _chip(
                              'Active',
                              const Color(0xFFD1FAE5),
                              const Color(0xFF166534),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3E8FF),
                      foregroundColor: const Color(0xFF7C3AED),
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
    final t = _teacher!;
    final classes = t['classes'] as List<dynamic>? ?? [];
    final subjects = t['subjects'] as List<dynamic>? ?? [];

    return Row(
      children: [
        Expanded(
          child: _statTile(
            Icons.class_rounded,
            'Classes',
            '${classes.length}',
            const Color(0xFF3B6FF5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _statTile(
            Icons.menu_book_rounded,
            'Subjects',
            '${subjects.length}',
            const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _statTile(
            Icons.apartment_rounded,
            'Department',
            '${t['department']}'.length > 8
                ? '${'${t['department']}'.substring(0, 8)}…'
                : '${t['department']}',
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
    if (gender == 'MALE') return 'Gent';
    if (gender == 'FEMALE') return 'Lady';
    return gender;
  }
}
