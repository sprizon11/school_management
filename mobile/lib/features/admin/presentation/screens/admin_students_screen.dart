import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/skeleton.dart';
import '../widgets/admin_fab.dart';
import '../widgets/admin_screen_header.dart';
import '../widgets/admin_search_field.dart';
import '../../../../core/widgets/stat_card.dart';
import 'admin_add_student_flow_screen.dart';
import 'admin_student_detail_screen.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  static const _hPad = 16.0;
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF6D5DE8);

  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  static const _allStudentsLimit = 1000;
  bool _loading = true;
  String? _classFilter;
  String? _genderFilter;
  String _sort = 'name_asc';
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
      setState(() => _loading = true);
    }
    try {
      final dio = ref.read(dioProvider);
      final statsFuture = dio.get('/admin/students/stats');
      final listFuture = dio.get(
        '/admin/students',
        queryParameters: {
          'page': 1,
          'limit': _allStudentsLimit,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          if (_classFilter != null) 'classId': _classFilter,
        },
      );
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      final list = listRes.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = list['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isFiltered =>
      _classFilter != null ||
      _search.text.trim().isNotEmpty ||
      _genderFilter != null;

  List<dynamic> get _visibleItems {
    var list = _genderFilter == null
        ? [..._items]
        : _items
              .where((i) => '${(i as Map)['gender']}' == _genderFilter)
              .toList();
    switch (_sort) {
      case 'name_asc':
        list.sort(
          (a, b) => '${(a as Map)['fullName']}'.toLowerCase().compareTo(
            '${(b as Map)['fullName']}'.toLowerCase(),
          ),
        );
      case 'name_desc':
        list.sort(
          (a, b) => '${(b as Map)['fullName']}'.toLowerCase().compareTo(
            '${(a as Map)['fullName']}'.toLowerCase(),
          ),
        );
      case 'roll':
        list.sort(
          (a, b) => _toInt(
            (a as Map)['rollNumber'],
          ).compareTo(_toInt((b as Map)['rollNumber'])),
        );
      case 'class':
        list.sort((a, b) {
          final am = a as Map;
          final bm = b as Map;
          final g = _toInt(am['grade']).compareTo(_toInt(bm['grade']));
          if (g != 0) return g;
          return '${am['section']}'.compareTo('${bm['section']}');
        });
    }
    return list;
  }

  ImageProvider? _studentAvatar(String? url) {
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

  Map<String, dynamic> get _displayStats {
    if (!_isFiltered && _stats != null) return _stats!;
    final boys = _items
        .where((i) => '${(i as Map)['gender']}' == 'MALE')
        .length;
    final girls = _items
        .where((i) => '${(i as Map)['gender']}' == 'FEMALE')
        .length;
    return {'total': _items.length, 'boys': boys, 'girls': girls};
  }

  void _openStudent(Map<String, dynamic> student) {
    final id = student['id'] as String?;
    if (id == null) return;
    openSmoothPage(context, AdminStudentDetailScreen(studentId: id));
  }

  Future<void> _openAddStudent() async {
    final added = await Navigator.of(
      context,
    ).push<bool>(SmoothPageRoute(page: const AdminAddStudentFlowScreen()));
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return AdminFabScaffold(
      fab: AdminFab(
        icon: Icons.add_rounded,
        tooltip: 'Add student',
        onTap: _openAddStudent,
      ),
      child: ColoredBox(
        color: const Color(0xFFF4F6FA),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: AdminScreenBody(
                child: _loading && _stats == null
                    ? _loadingSkeleton()
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          EntranceFade(child: _statsRow()),
                          const SizedBox(height: 12),
                          EntranceFade(
                            delay: const Duration(milliseconds: 60),
                            child: _searchRow(),
                          ),
                          _listHeader(visible.length),
                          Expanded(
                            child: RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => _load(showOverlay: true),
                              child: visible.isEmpty
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [_emptyState()],
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        left: _hPad,
                                        right: _hPad,
                                        bottom: bottomInset,
                                      ),
                                      itemCount: visible.length,
                                      itemBuilder: (_, i) => EntranceFadeItem(
                                        index: i,
                                        child: _studentRow(
                                          visible[i] as Map<String, dynamic>,
                                          first: i == 0,
                                          last: i == visible.length - 1,
                                        ),
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

  Widget _loadingSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Mirrors the real layout — stat row, then search — so nothing
          // jumps when the data lands.
          SkeletonBox(height: 52, borderRadius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 50, borderRadius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 300, borderRadius: 18),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------
  Widget _header() {
    return AdminScreenHeader(
      title: 'Students',
      leading: Builder(
        builder: (context) => AdminHeaderIconButton(
          icon: Icons.segment_rounded,
          plain: true,
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      subtitle: 'Manage and view all students',
      actions: [
        AdminHeaderIconButton(
          icon: Icons.download_rounded,
          onTap: () => _snack('Export coming soon'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Stat cards
  // ---------------------------------------------------------------------
  /// Total / Boys / Girls only. Three fit the width, so they sit in a plain
  /// Row — no horizontal scroller, nothing clipped off the right edge.
  /// Tapping Boys or Girls still filters the list.
  Widget _statsRow() {
    final stats = _displayStats;
    final total = _toInt(stats['total']);
    final boys = _toInt(stats['boys']);
    final girls = _toInt(stats['girls']);

    return StatRow(
      cards: [
        StatCard(
          icon: Icons.groups_rounded,
          color: _purple,
          value: _formatNum(total),
          // "Total Students" would ellipsis at this width; the screen is
          // already titled Students, so the noun is redundant.
          label: 'Total',
          selected: _genderFilter == null,
          onTap: () => setState(() => _genderFilter = null),
        ),
        StatCard(
          icon: Icons.man_rounded,
          color: const Color(0xFF22C55E),
          value: _formatNum(boys),
          label: 'Boys',
          selected: _genderFilter == 'MALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'MALE' ? null : 'MALE',
          ),
        ),
        StatCard(
          icon: Icons.woman_rounded,
          color: const Color(0xFFEC4899),
          value: _formatNum(girls),
          label: 'Girls',
          selected: _genderFilter == 'FEMALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'FEMALE' ? null : 'FEMALE',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Search + filter
  // ---------------------------------------------------------------------
  Widget _searchRow() {
    return AdminSearchField(
      controller: _search,
      hint: 'Search students by name, roll no., class...',
      accent: _purple,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _load(),
      onCleared: _load,
    );
  }

  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 14, _hPad, 10),
      child: Row(
        children: [
          Text(
            'All Students ($count)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // Gender filter comes from the stat cards; this is the way back.
          if (_genderFilter != null)
            GestureDetector(
              onTap: () => setState(() => _genderFilter = null),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    _genderFilter == 'MALE' ? 'Boys' : 'Girls',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.close_rounded, size: 14, color: _purple),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _studentRow(
    Map<String, dynamic> s, {
    required bool first,
    required bool last,
  }) {
    final gender = '${s['gender']}';
    final isFemale = gender == 'FEMALE';
    final tint = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final avatar = _studentAvatar(s['avatarUrl'] as String?);
    final email = '${s['email'] ?? ''}';
    final phone = '${s['phone'] ?? ''}';
    final code = '${s['studentCode'] ?? ''}';
    final line2 = email.isNotEmpty ? email : code;
    final grade = '${s['grade'] ?? ''}';
    final section = '${s['section'] ?? ''}';
    final roll = '${s['rollNumber'] ?? '—'}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: first ? const Radius.circular(18) : Radius.zero,
          bottom: last ? const Radius.circular(18) : Radius.zero,
        ),
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFF0F1F6)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openStudent(s),
          borderRadius: BorderRadius.vertical(
            top: first ? const Radius.circular(18) : Radius.zero,
            bottom: last ? const Radius.circular(18) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    image: avatar != null
                        ? DecorationImage(image: avatar, fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatar == null
                      ? Icon(
                          isFemale ? Icons.face_3_rounded : Icons.face_rounded,
                          color: tint,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${s['fullName']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _ink.withValues(alpha: 0.5),
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Class $grade - $section',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Roll No. ${roll.padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                _rowMenu(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowMenu(Map<String, dynamic> s) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: Color(0xFF9CA3AF),
      ),
      padding: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'view') _openStudent(s);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: _purple),
              SizedBox(width: 10),
              Text('View details'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Filter + sort sheets
  // ---------------------------------------------------------------------
  Widget _emptyState() {
    final filtered = _isFiltered;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 40, _hPad, 40),
      child: Column(
        children: [
          Container(
            height: 92,
            width: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.08),
            ),
            child: Icon(
              filtered ? Icons.search_off_rounded : Icons.groups_2_outlined,
              size: 44,
              color: _purple.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            filtered ? 'No matching students' : 'No students yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try adjusting your search or filters.'
                : 'Add your first student to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          if (filtered)
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _search.clear();
                  _classFilter = null;
                  _genderFilter = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: BorderSide(color: _purple.withValues(alpha: 0.4)),
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
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _purple,
        duration: const Duration(seconds: 2),
      ),
    );
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

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
