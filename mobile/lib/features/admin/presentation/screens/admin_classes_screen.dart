import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_fab.dart';
import '../widgets/admin_screen_header.dart';
import '../widgets/admin_search_field.dart';
import '../widgets/admin_stat_card.dart';
import '../../../../core/widgets/motion.dart';
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
        _items = parseClassesResponse(listRes.data);
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ??
            'Could not load classes';
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
    final added = await Navigator.of(
      context,
    ).push<bool>(SmoothPageRoute(page: const AdminAddClassScreen()));
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
    return AdminFabScaffold(
      fab: AdminFab(
        icon: Icons.add_rounded,
        tooltip: 'Add class',
        onTap: _openAddClass,
      ),
      child: ColoredBox(
        color: const Color(0xFFF4F6FA),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: AdminScreenBody(
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
                          EntranceFade(child: _statsRow()),
                          const SizedBox(height: 12),
                          EntranceFade(
                            delay: const Duration(milliseconds: 60),
                            child: _searchRow(),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
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
                                      itemBuilder: (_, i) => EntranceFadeItem(
                                        index: i,
                                        child: _classCard(_visibleItems[i], i),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return AdminScreenHeader(
      title: 'Classes',
      leading: Builder(
        builder: (context) => AdminHeaderIconButton(
          icon: Icons.segment_rounded,
          plain: true,
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      subtitle: 'Manage classes, teachers & students',
      actions: [],
    );
  }

  Widget _statsRow() {
    final totalClasses = _stats?['totalClasses'] as int? ?? _items.length;
    final totalStudents = _stats?['totalStudents'] as int? ?? 0;
    final withTeacher = _withTeacherCount;

    return AdminStatRow(
      cards: [
        AdminStatCard(
          icon: Icons.class_rounded,
          color: const Color(0xFF7C3AED),
          value: _formatNum(totalClasses),
          label: 'Classes',
        ),
        AdminStatCard(
          icon: Icons.groups_rounded,
          color: const Color(0xFF3B6FF5),
          value: _formatNum(totalStudents),
          label: 'Students',
        ),
        AdminStatCard(
          icon: Icons.school_rounded,
          color: const Color(0xFF16A34A),
          value: _formatNum(withTeacher),
          label: 'Assigned',
        ),
      ],
    );
  }

  Widget _searchRow() {
    return AdminSearchField(
      controller: _search,
      hint: 'Search class, grade or teacher...',
      accent: const Color(0xFF7C3AED),
      onChanged: (_) => setState(() {}),
      onCleared: () => setState(() {}),
    );
  }

  Widget _classCard(dynamic item, int index) {
    final c = item as Map<String, dynamic>;
    final color = _classColor(index);
    final teacher = c['classTeacher'] as Map<String, dynamic>?;
    final studentCount = c['studentCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: () => _openClass(c),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
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
                        _classBadgeLabel(c),
                        textAlign: TextAlign.center,
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
                            _classSubtitle(c),
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
                        backgroundImage: _avatarImage(
                          teacher['avatarUrl'] as String?,
                        ),
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
    );
  }

  Widget _miniChip(IconData icon, String label, Color bg, Color color) {
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
    final searching = _search.text.trim().isNotEmpty;
    final title = searching ? 'No matching classes' : 'No classes yet';
    final subtitle = searching
        ? 'Try a different class, grade or teacher.'
        : 'Create your first class to start adding students.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.class_rounded,
                size: 46,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            // No "Add Class" button here — the + FAB already offers that, and
            // two primary actions on one empty screen is one too many. Clear
            // search stays: the FAB doesn't cover it.
            if (searching) ...[
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => setState(() => _search.clear()),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFFEF4444),
            ),
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

String _classBadgeLabel(Map<String, dynamic> c) =>
    '${c['grade']}${c['section']}';

String _classSubtitle(Map<String, dynamic> c) {
  final grade = c['grade'];
  final parts = <String>[];
  if (grade == 11 || grade == 12) {
    final group = (c['streamGroup'] ?? c['category'] ?? '').toString().trim();
    if (group.isNotEmpty) parts.add('Group: $group');
  } else if (c['category'] != null) {
    parts.add('${c['category']}');
  }
  final room = c['room']?.toString().trim();
  if (room != null && room.isNotEmpty) {
    parts.add('Room $room');
  }
  return parts.join(' · ');
}
