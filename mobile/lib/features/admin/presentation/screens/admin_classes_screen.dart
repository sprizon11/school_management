import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_add_class_screen.dart';
import 'admin_class_detail_screen.dart';

class AdminClassesScreen extends ConsumerStatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  ConsumerState<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends ConsumerState<AdminClassesScreen> {
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showOverlay = false}) async {
    if (_stats == null || showOverlay) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dio = ref.read(dioProvider);
      final statsFuture = dio.get('/admin/classes/stats');
      final listFuture = dio.get(
        '/admin/classes',
        queryParameters: {
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = listRes.data as List<dynamic>;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message']?.toString() ?? 'Could not load classes';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load classes';
        _loading = false;
      });
    }
  }

  List<dynamic> get _visibleItems {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) {
      final c = i as Map;
      final name = '${c['name']}'.toLowerCase();
      final grade = '${c['grade']}'.toLowerCase();
      final section = '${c['section']}'.toLowerCase();
      final teacher = '${c['classTeacher']?['name'] ?? ''}'.toLowerCase();
      return name.contains(q) ||
          grade.contains(q) ||
          section.contains(q) ||
          teacher.contains(q);
    }).toList();
  }

  int get _withTeacherCount =>
      _items.where((i) => (i as Map)['classTeacher'] != null).length;

  Future<void> _openAddClass() async {
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: const AdminAddClassScreen()),
    );
    if (added == true) _load();
  }

  void _openClass(Map<String, dynamic> cls) {
    final id = cls['id'] as String?;
    if (id == null) return;
    openSmoothPage(context, AdminClassDetailScreen(classId: id));
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

  Color _classColor(int index) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF2563EB),
      Color(0xFF16A34A),
      Color(0xFFEA580C),
      Color(0xFFDB2777),
    ];
    return colors[index % colors.length];
  }

  String _formatNum(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final pos = s.length - i - 1;
      if (pos > 0 && pos % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: const Color(0xFFF4F6FA),
      child: Column(
        children: [
          _header(topPad),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: _loading && _stats == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SkeletonBox(height: 72, borderRadius: 16),
                            SizedBox(height: 12),
                            SkeletonBox(height: 48, borderRadius: 14),
                            SizedBox(height: 12),
                            SkeletonBox(height: 200, borderRadius: 16),
                          ],
                        ),
                      )
                    : _error != null && _stats == null
                    ? _errorState()
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          _statsRow(),
                          const SizedBox(height: 12),
                          _actionButtons(),
                          const SizedBox(height: 12),
                          _searchRow(),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _loading
                                ? const Center(child: CircularProgressIndicator())
                                : _visibleItems.isEmpty
                                ? _emptyState()
                                : RefreshIndicator(
                                    onRefresh: () => _load(showOverlay: true),
                                    child: ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        4,
                                        12,
                                        88,
                                      ),
                                      itemCount: _visibleItems.length,
                                      itemBuilder: (_, i) =>
                                          _classCard(_visibleItems[i], i),
                                    ),
                                  ),
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

  Widget _header(double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3FC9), Color(0xFF2368FF), Color(0xFF4388FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage classes, teachers & students',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _headerIconButton(Icons.refresh_rounded, onTap: () => _load(showOverlay: true)),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, {VoidCallback? onTap}) {
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

  Widget _statsRow() {
    final totalClasses = _stats?['totalClasses'] as int? ?? _items.length;
    final totalStudents = _stats?['totalStudents'] as int? ?? 0;
    final withTeacher = _withTeacherCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              accent: const Color(0xFF7C3AED),
              accentLight: const Color(0xFFF3E8FF),
              icon: Icons.class_rounded,
              label: 'Classes',
              value: _formatNum(totalClasses),
              badge: 'Total',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              accent: const Color(0xFF3B6FF5),
              accentLight: const Color(0xFFE8EFFF),
              icon: Icons.groups_rounded,
              label: 'Students',
              value: _formatNum(totalStudents),
              badge: 'All',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              accent: const Color(0xFF16A34A),
              accentLight: const Color(0xFFE8F8EE),
              icon: Icons.school_rounded,
              label: 'Assigned',
              value: _formatNum(withTeacher),
              badge: 'Teacher',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Color accent,
    required Color accentLight,
    required IconData icon,
    required String label,
    required String value,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentLight),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.75)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _openAddClass,
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add Class',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search class, grade or teacher...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B6FF5)),
          ),
        ),
      ),
    );
  }

  Widget _classCard(dynamic item, int index) {
    final c = item as Map<String, dynamic>;
    final color = _classColor(index);
    final teacher = c['classTeacher'] as Map<String, dynamic>?;
    final studentCount = c['studentCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openClass(c),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${c['grade']}${c['section']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['name']}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c['category']}${c['room'] != null ? ' · Room ${c['room']}' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _miniChip(
                                  Icons.groups_rounded,
                                  '$studentCount students',
                                  const Color(0xFFEEF4FF),
                                  AppColors.primary,
                                ),
                                if (teacher != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: _miniChip(
                                      Icons.person_rounded,
                                      '${teacher['name']}',
                                      const Color(0xFFF3E8FF),
                                      const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (teacher != null)
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF3E8FF),
                          backgroundImage:
                              _avatarImage(teacher['avatarUrl'] as String?),
                          child: teacher['avatarUrl'] == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: Color(0xFF7C3AED),
                                )
                              : null,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_off_outlined,
                            size: 18,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(
    IconData icon,
    String label,
    Color bg,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _search.text.trim().isNotEmpty
                  ? 'No classes match your search'
                  : 'No classes yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            if (_search.text.trim().isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Create your first class to start adding students.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openAddClass,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Class'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
