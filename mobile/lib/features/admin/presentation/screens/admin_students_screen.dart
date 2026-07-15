import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
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
  List<dynamic> _classes = [];
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
      final classesFuture =
          ref.read(adminClassesProvider.future).catchError((_) => <dynamic>[]);
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      final classes = await classesFuture;
      final list = listRes.data as Map<String, dynamic>;
      var classFilter = _classFilter;
      if (classFilter != null &&
          !classes.any((c) => '${(c as Map)['id']}' == classFilter)) {
        classFilter = null;
      }
      if (!mounted) return;
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = list['items'] as List<dynamic>? ?? [];
        _classes = classes;
        _classFilter = classFilter;
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
        list.sort((a, b) => '${(a as Map)['fullName']}'
            .toLowerCase()
            .compareTo('${(b as Map)['fullName']}'.toLowerCase()));
      case 'name_desc':
        list.sort((a, b) => '${(b as Map)['fullName']}'
            .toLowerCase()
            .compareTo('${(a as Map)['fullName']}'.toLowerCase()));
      case 'roll':
        list.sort((a, b) => _toInt((a as Map)['rollNumber'])
            .compareTo(_toInt((b as Map)['rollNumber'])));
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
    final boys =
        _items.where((i) => '${(i as Map)['gender']}' == 'MALE').length;
    final girls =
        _items.where((i) => '${(i as Map)['gender']}' == 'FEMALE').length;
    return {'total': _items.length, 'boys': boys, 'girls': girls};
  }

  void _openStudent(Map<String, dynamic> student) {
    final id = student['id'] as String?;
    if (id == null) return;
    openSmoothPage(context, AdminStudentDetailScreen(studentId: id));
  }

  Future<void> _openAddStudent() async {
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: const AdminAddStudentFlowScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    return ColoredBox(
      color: const Color(0xFFF5F5FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _loading && _stats == null
                  ? _loadingSkeleton()
                  : RefreshIndicator(
                      color: _purple,
                      onRefresh: () => _load(showOverlay: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _statsRow()),
                          SliverToBoxAdapter(child: _searchRow()),
                          SliverToBoxAdapter(child: _listHeader(visible.length)),
                          if (visible.isEmpty)
                            SliverToBoxAdapter(child: _emptyState())
                          else
                            SliverPadding(
                              padding: EdgeInsets.only(
                                  left: _hPad, right: _hPad, bottom: bottomInset),
                              sliver: SliverList.builder(
                                itemCount: visible.length,
                                itemBuilder: (_, i) => _studentRow(
                                  visible[i] as Map<String, dynamic>,
                                  first: i == 0,
                                  last: i == visible.length - 1,
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
          SkeletonBox(height: 96, borderRadius: 18),
          SizedBox(height: 12),
          SkeletonBox(height: 52, borderRadius: 14),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Students',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage and view all students',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _ink.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _squareIconButton(
            Icons.download_rounded,
            onTap: () => _snack('Export coming soon'),
          ),
          const SizedBox(width: 10),
          _addButton(),
        ],
      ),
    );
  }

  Widget _squareIconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: _ink, size: 22),
        ),
      ),
    );
  }

  Widget _addButton() {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAddStudent,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C6FF2), Color(0xFF6355E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'Add Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
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

  // ---------------------------------------------------------------------
  // Stat cards
  // ---------------------------------------------------------------------
  Widget _statsRow() {
    final stats = _displayStats;
    final total = _toInt(stats['total']);
    final boys = _toInt(stats['boys']);
    final girls = _toInt(stats['girls']);
    final classes = _classes.length;

    return SizedBox(
      height: 128,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 8),
        physics: const BouncingScrollPhysics(),
        children: [
          _statCard(
            icon: Icons.groups_rounded,
            color: _purple,
            value: _formatNum(total),
            label: 'Total Students',
            fraction: 1,
            selected: _genderFilter == null,
            onTap: () => setState(() => _genderFilter = null),
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.man_rounded,
            color: const Color(0xFF22C55E),
            value: _formatNum(boys),
            label: 'Boys',
            fraction: total > 0 ? boys / total : 0,
            selected: _genderFilter == 'MALE',
            onTap: () => setState(() =>
                _genderFilter = _genderFilter == 'MALE' ? null : 'MALE'),
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.woman_rounded,
            color: const Color(0xFFEC4899),
            value: _formatNum(girls),
            label: 'Girls',
            fraction: total > 0 ? girls / total : 0,
            selected: _genderFilter == 'FEMALE',
            onTap: () => setState(() =>
                _genderFilter = _genderFilter == 'FEMALE' ? null : 'FEMALE'),
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.school_rounded,
            color: const Color(0xFF3B82F6),
            value: _formatNum(classes),
            label: 'Total Classes',
            fraction: 1,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required double fraction,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _ink,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _ink.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Search + filter
  // ---------------------------------------------------------------------
  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 4),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 21, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 13.5),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search students by name, roll no., class...',
                  hintStyle:
                      TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
            if (_search.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  _load();
                },
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ),
            Container(
              height: 22,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFFE5E7EB),
            ),
            GestureDetector(
              onTap: _showFilterSheet,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: _classFilter != null ? _purple : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _classFilter != null
                          ? _purple
                          : const Color(0xFF6B7280),
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

  // ---------------------------------------------------------------------
  // List header (All Students + sort)
  // ---------------------------------------------------------------------
  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 10),
      child: Row(
        children: [
          Text(
            'All Students ($count)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showSortSheet,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  'Sort by: ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  _sortLabel(_sort),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _purple,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(String s) {
    switch (s) {
      case 'name_desc':
        return 'Name Z-A';
      case 'roll':
        return 'Roll No.';
      case 'class':
        return 'Class';
      default:
        return 'Name A-Z';
    }
  }

  // ---------------------------------------------------------------------
  // Student row
  // ---------------------------------------------------------------------
  Widget _studentRow(Map<String, dynamic> s,
      {required bool first, required bool last}) {
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
                          horizontal: 9, vertical: 4),
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
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF9CA3AF)),
      padding: EdgeInsets.zero,
      color: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 14, 20, 20 + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Filter Students',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 16),
              const Text('Gender',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _filterChip('All', _genderFilter == null,
                      () => setSheet(() => _genderFilter = null)),
                  const SizedBox(width: 8),
                  _filterChip('Boys', _genderFilter == 'MALE',
                      () => setSheet(() => _genderFilter = 'MALE')),
                  const SizedBox(width: 8),
                  _filterChip('Girls', _genderFilter == 'FEMALE',
                      () => setSheet(() => _genderFilter = 'FEMALE')),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Class',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All Classes', _classFilter == null,
                      () => setSheet(() => _classFilter = null)),
                  for (final c in _classes)
                    _filterChip(
                      'Class ${(c as Map)['grade']}${c['section']}',
                      _classFilter == '${c['id']}',
                      () => setSheet(() => _classFilter = '${c['id']}'),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _load();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _purple : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    const options = {
      'name_asc': 'Name A-Z',
      'name_desc': 'Name Z-A',
      'roll': 'Roll No.',
      'class': 'Class',
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            12, 14, 12, 12 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            for (final e in options.entries)
              ListTile(
                title: Text(e.value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: _sort == e.key
                    ? const Icon(Icons.check_rounded, color: _purple)
                    : null,
                onTap: () {
                  setState(() => _sort = e.key);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Empty state
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
