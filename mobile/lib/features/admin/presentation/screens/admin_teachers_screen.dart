import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_fab.dart';
import '../widgets/admin_screen_header.dart';
import '../widgets/admin_search_field.dart';
import '../widgets/admin_stat_card.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_add_teacher_screen.dart';
import 'admin_teacher_detail_screen.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() =>
      _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  static const _ink = Color(0xFF1A1533);
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  static const _allTeachersLimit = 1000;
  bool _loading = true;
  String? _error;
  String? _genderFilter;
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
      final statsFuture = dio.get('/admin/teachers/stats');
      final listFuture = dio.get(
        '/admin/teachers',
        queryParameters: {
          'page': 1,
          'limit': _allTeachersLimit,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      final list = listRes.data as Map<String, dynamic>;
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = list['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      setState(() {
        _error = msg?.toString() ?? 'Could not load teachers';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load teachers';
        _loading = false;
      });
    }
  }

  bool get _isFiltered =>
      _search.text.trim().isNotEmpty || _genderFilter != null;

  List<dynamic> get _visibleItems {
    var items = _items;
    if (_genderFilter != null) {
      items = items
          .where((i) => '${(i as Map)['gender']}' == _genderFilter)
          .toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) {
      final t = i as Map;
      final name = '${t['fullName']}'.toLowerCase();
      final dept = '${t['department']}'.toLowerCase();
      final code = '${t['employeeCode']}'.toLowerCase();
      return name.contains(q) || dept.contains(q) || code.contains(q);
    }).toList();
  }

  Map<String, dynamic> get _displayStats {
    if (!_isFiltered && _stats != null) {
      return {
        'total': _stats!['total'] ?? 0,
        'male': _stats!['male'] ?? 0,
        'female': _stats!['female'] ?? 0,
        'malePercent': _stats!['malePercent'] ?? 0,
        'femalePercent': _stats!['femalePercent'] ?? 0,
      };
    }
    final gents = _items
        .where((i) => '${(i as Map)['gender']}' == 'MALE')
        .length;
    final ladies = _items
        .where((i) => '${(i as Map)['gender']}' == 'FEMALE')
        .length;
    final total = _items.length;
    return {
      'total': total,
      'male': gents,
      'female': ladies,
      'malePercent': total > 0 ? (gents / total * 1000).round() / 10 : 0,
      'femalePercent': total > 0 ? (ladies / total * 1000).round() / 10 : 0,
    };
  }

  Future<void> _openTeacher(Map<String, dynamic> teacher) async {
    final id = teacher['id'] as String?;
    if (id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: AdminTeacherDetailScreen(teacherId: id)),
    );
    if (changed == true) _load();
  }

  Future<void> _openAddTeacher() async {
    final added = await Navigator.of(
      context,
    ).push<bool>(SmoothPageRoute(page: const AdminAddTeacherScreen()));
    if (added == true) _load();
  }

  ImageProvider? _teacherAvatar(String? url) {
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
        tooltip: 'Add teacher',
        onTap: _openAddTeacher,
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
                          _listHeader(_visibleItems.length),
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
                                        2,
                                        12,
                                        88,
                                      ),
                                      itemCount: _visibleItems.length,
                                      itemBuilder: (_, i) => EntranceFadeItem(
                                        index: i,
                                        child: _teacherRow(_visibleItems[i]),
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
      title: 'Teachers',
      leading: Builder(
        builder: (context) => AdminHeaderIconButton(
          icon: Icons.segment_rounded,
          plain: true,
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      subtitle: 'Manage and view all teacher details',
      actions: [],
    );
  }

  Widget _statsRow() {
    final stats = _displayStats;
    final total = stats['total'] as int? ?? 0;
    final gents = stats['male'] as int? ?? 0;
    final ladies = stats['female'] as int? ?? 0;

    return AdminStatRow(
      cards: [
        AdminStatCard(
          icon: Icons.groups_rounded,
          color: const Color(0xFF3B6FF5),
          value: _formatNum(total),
          label: 'Total',
          selected: _genderFilter == null,
          onTap: () => setState(() => _genderFilter = null),
        ),
        AdminStatCard(
          icon: Icons.man_rounded,
          color: const Color(0xFF16A34A),
          value: _formatNum(gents),
          label: 'Gents',
          selected: _genderFilter == 'MALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'MALE' ? null : 'MALE',
          ),
        ),
        AdminStatCard(
          icon: Icons.woman_rounded,
          color: const Color(0xFFDB2777),
          value: _formatNum(ladies),
          label: 'Ladies',
          selected: _genderFilter == 'FEMALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'FEMALE' ? null : 'FEMALE',
          ),
        ),
      ],
    );
  }

  Widget _searchRow() {
    return AdminSearchField(
      controller: _search,
      hint: 'Search by name, department or code...',
      accent: const Color(0xFF3B6FF5),
      onChanged: (_) => setState(() {}),
      onCleared: () => setState(() {}),
    );
  }

  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Text(
            'All Teachers ($count)',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (_genderFilter != null)
            GestureDetector(
              onTap: () => setState(() => _genderFilter = null),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    _genderFilter == 'MALE' ? 'Gents' : 'Ladies',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _teacherRow(dynamic item) {
    final t = item as Map<String, dynamic>;
    final name = '${t['fullName'] ?? ''}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final gender = '${t['gender'] ?? 'MALE'}';
    final accent = gender == 'FEMALE'
        ? const Color(0xFFDB2777)
        : const Color(0xFF2563EB);
    final avatar = _teacherAvatar(t['avatarUrl'] as String?);
    final department = '${t['department'] ?? ''}';
    final code = '${t['employeeCode'] ?? ''}';
    final classes = '${t['classes'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        // The whole card opens the teacher. Previously only the name was
        // tappable, so the avatar and department were dead zones.
        onTap: () => _openTeacher(t),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEFF5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with a soft accent ring — reads as a person, not a
              // table cell.
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          initial,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _metaChip(department, accent),
                        if (classes.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Grade $classes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _ink.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _ink.withValues(alpha: 0.4),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _ink.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small tinted label for a teacher's department.
  Widget _metaChip(String text, Color accent) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  Widget _emptyState() {
    final filtered = _isFiltered;
    final title = _genderFilter == 'MALE'
        ? 'No gents found'
        : _genderFilter == 'FEMALE'
        ? 'No ladies found'
        : filtered
        ? 'No matching teachers'
        : 'No teachers yet';
    final subtitle = filtered
        ? 'Try adjusting your search or filters.'
        : 'Add your first teacher to get started.';

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
                filtered ? Icons.search_off_rounded : Icons.school_rounded,
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
            // No "Add Teacher" button here — the + FAB already offers that.
            // Clear filters stays: the FAB doesn't cover it.
            if (filtered) ...[
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _search.clear();
                    _genderFilter = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear filters'),
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
