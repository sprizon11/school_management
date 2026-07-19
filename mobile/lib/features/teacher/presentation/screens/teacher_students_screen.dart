import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/providers/auth_provider.dart';
import 'teacher_add_student_screen.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF635BFF);
  static const _perPage = 10;

  List<dynamic> _classes = [];
  String? _classId;
  List<dynamic> _students = [];
  Map<String, dynamic>? _classInfo;
  bool _loading = true;
  String _query = '';
  String? _genderFilter;
  int _page = 0;
  bool _searchOpen = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/teacher/classes');
      final list = res.data as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _classes = list;
        _classId = list.isNotEmpty ? '${(list.first as Map)['id']}' : null;
      });
      if (_classId != null) {
        await _loadStudents(_classId!);
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStudents(String classId) async {
    _search.clear();
    setState(() {
      _loading = true;
      _query = '';
      _genderFilter = null;
      _page = 0;
    });
    try {
      final dio = ref.read(dioProvider);
      final detail = await dio.get('/teacher/classes/$classId');
      final roster = await dio.get(
        '/teacher/classes/$classId/students',
        queryParameters: {'limit': 200},
      );
      if (!mounted) return;
      setState(() {
        _classId = classId;
        _classInfo = detail.data as Map<String, dynamic>;
        _students = (roster.data as Map)['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isClassTeacher {
    final teacherId = ref.read(authProvider).user?.teacherId;
    final classTeacherId = _classInfo?['classTeacherId'];
    return teacherId != null && teacherId == classTeacherId;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    var list = _students
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (_genderFilter != null) {
      list = list.where((s) => '${s['gender']}' == _genderFilter).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((s) {
        final name = '${s['fullName'] ?? ''}'.toLowerCase();
        final roll = '${s['rollNumber'] ?? ''}'.toLowerCase();
        final code = '${s['studentCode'] ?? ''}'.toLowerCase();
        final email = '${s['email'] ?? ''}'.toLowerCase();
        return name.contains(q) ||
            roll.contains(q) ||
            code.contains(q) ||
            email.contains(q);
      }).toList();
    }
    list.sort(
      (a, b) => _toInt(a['rollNumber']).compareTo(_toInt(b['rollNumber'])),
    );
    return list;
  }

  Future<void> _openAddStudent() async {
    if (_classId == null || _classInfo == null) return;
    final label = '${_classInfo!['grade']}${_classInfo!['section']}';
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(
        page: TeacherAddStudentScreen(classId: _classId!, classLabel: label),
      ),
    );
    if (added == true && _classId != null) _loadStudents(_classId!);
  }

  String get _classLabel => _classInfo != null
      ? 'Class ${_classInfo!['grade']} - ${_classInfo!['section']}'
      : 'No class';

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = _students.length;
    final active = _students
        .where((s) => '${(s as Map)['status']}' == 'ACTIVE')
        .length;
    final pageCount = (filtered.length / _perPage).ceil().clamp(1, 9999);
    if (_page >= pageCount) _page = 0;
    final start = _page * _perPage;
    final pageItems = filtered.skip(start).take(_perPage).toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;

    return ColoredBox(
      color: const Color(0xFFF5F5FB),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                if (_searchOpen) _searchField(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _purple),
                        )
                      : RefreshIndicator(
                          color: _purple,
                          onRefresh: () => _classId != null
                              ? _loadStudents(_classId!)
                              : _loadClasses(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              6,
                              16,
                              bottomInset,
                            ),
                            children: [
                              _statsRow(total, active),
                              const SizedBox(height: 14),
                              _classFilterRow(),
                              const SizedBox(height: 16),
                              _listTab(filtered.length),
                              const SizedBox(height: 10),
                              if (filtered.isEmpty)
                                _emptyState()
                              else ...[
                                _listCard(pageItems),
                                const SizedBox(height: 14),
                                _pagination(filtered.length, pageCount),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                  'Manage and view your students',
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
          _squareIcon(
            _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            onTap: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _search.clear();
                _query = '';
              }
            }),
          ),
          const SizedBox(width: 10),
          if (_isClassTeacher) _addButton(),
        ],
      ),
    );
  }

  Widget _squareIcon(IconData icon, {required VoidCallback onTap}) {
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openAddStudent,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B74FF), Color(0xFF5B52E8)],
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 5),
                Text(
                  'Add Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                autofocus: true,
                style: const TextStyle(fontSize: 13.5),
                onChanged: (v) => setState(() {
                  _query = v;
                  _page = 0;
                }),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search by name, roll or email',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  /// Total / Boys / Girls — same three cards as the admin Students screen,
  /// via the shared StatCard. Tapping Boys or Girls filters the roster, which
  /// is what the existing _genderFilter already drives.
  Widget _statsRow(int total, int active) {
    final boys = _students
        .where((s) => '${(s as Map)['gender']}' == 'MALE')
        .length;
    final girls = _students
        .where((s) => '${(s as Map)['gender']}' == 'FEMALE')
        .length;

    return StatRow(
      cards: [
        StatCard(
          icon: Icons.groups_rounded,
          color: _purple,
          value: '$total',
          label: 'Total',
          selected: _genderFilter == null,
          onTap: () => setState(() => _genderFilter = null),
        ),
        StatCard(
          icon: Icons.man_rounded,
          color: const Color(0xFF22C55E),
          value: '$boys',
          label: 'Boys',
          selected: _genderFilter == 'MALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'MALE' ? null : 'MALE',
          ),
        ),
        StatCard(
          icon: Icons.woman_rounded,
          color: const Color(0xFFEC4899),
          value: '$girls',
          label: 'Girls',
          selected: _genderFilter == 'FEMALE',
          onTap: () => setState(
            () => _genderFilter = _genderFilter == 'FEMALE' ? null : 'FEMALE',
          ),
        ),
      ],
    );
  }

  Widget _classFilterRow() {
    return Row(
      children: [
        Expanded(
          child: _pill(
            Icons.school_rounded,
            'Class',
            _classInfo != null
                ? 'Class ${_classInfo!['grade']} - ${_classInfo!['section']}'
                : 'Select',
            onTap: _classes.length > 1 ? _showClassSheet : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pill(
            Icons.tune_rounded,
            'Filter',
            _genderFilter == null
                ? 'All Students'
                : _genderFilter == 'MALE'
                ? 'Boys'
                : 'Girls',
            onTap: _showFilterSheet,
          ),
        ),
      ],
    );
  }

  Widget _pill(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: _purple),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: _ink.withValues(alpha: 0.45),
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: _ink.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listTab(int count) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Students ($count)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 60,
              decoration: BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  Widget _listCard(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _studentRow(items[i], first: i == 0, last: i == items.length - 1),
            if (i < items.length - 1)
              const Divider(
                height: 1,
                indent: 62,
                endIndent: 14,
                color: Color(0xFFF0F1F6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _studentRow(
    Map<String, dynamic> s, {
    required bool first,
    required bool last,
  }) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final email = '${s['email'] ?? ''}';
    final code = '${s['studentCode'] ?? ''}';
    final gender = '${s['gender']}';
    final isFemale = gender == 'FEMALE';
    final tint = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final isActive = '${s['status']}' == 'ACTIVE';
    final avatar = _avatar(s['avatarUrl'] as String?);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              image: avatar != null
                  ? DecorationImage(image: avatar, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatar == null
                ? Icon(
                    isFemale ? Icons.face_3_rounded : Icons.face_rounded,
                    color: tint,
                    size: 22,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll No. ${roll.padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  email.isNotEmpty ? email : code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _ink.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (isActive ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF))
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          _rowMenu(s),
        ],
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
        if (v == 'view') _showStudentSheet(s);
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
  Widget _pagination(int total, int pageCount) {
    final start = total == 0 ? 0 : _page * _perPage + 1;
    final end = ((_page + 1) * _perPage).clamp(0, total);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start to $end of $total students',
            style: TextStyle(fontSize: 12, color: _ink.withValues(alpha: 0.5)),
          ),
        ),
        _pageBtn(
          Icons.chevron_left_rounded,
          enabled: _page > 0,
          onTap: () => setState(() => _page--),
        ),
        const SizedBox(width: 6),
        for (var p = 0; p < pageCount && p < 3; p++) ...[
          if (p > 0) const SizedBox(width: 6),
          _pageNum(p),
        ],
        const SizedBox(width: 6),
        _pageBtn(
          Icons.chevron_right_rounded,
          enabled: _page < pageCount - 1,
          onTap: () => setState(() => _page++),
        ),
      ],
    );
  }

  Widget _pageBtn(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? _ink : _ink.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _pageNum(int p) {
    final selected = p == _page;
    return GestureDetector(
      onTap: () => setState(() => _page = p),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _purple.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _purple : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          '${p + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? _purple : _ink,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  void _showClassSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          14,
          12,
          12 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            const SizedBox(height: 8),
            for (final c in _classes)
              ListTile(
                title: Text(
                  'Class ${(c as Map)['grade']} - ${c['section']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: '${c['id']}' == _classId
                    ? const Icon(Icons.check_rounded, color: _purple)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _loadStudents('${c['id']}');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          14,
          12,
          12 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            const SizedBox(height: 8),
            for (final e in {
              null: 'All Students',
              'MALE': 'Boys',
              'FEMALE': 'Girls',
            }.entries)
              ListTile(
                title: Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _genderFilter == e.key
                    ? const Icon(Icons.check_rounded, color: _purple)
                    : null,
                onTap: () {
                  setState(() {
                    _genderFilter = e.key;
                    _page = 0;
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _grabber() => Container(
    width: 42,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  void _showStudentSheet(Map<String, dynamic> s) {
    final gender = '${s['gender']}';
    final isFemale = gender == 'FEMALE';
    final color = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final name = '${s['fullName'] ?? '?'}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            const SizedBox(height: 16),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _classLabel,
              style: TextStyle(
                fontSize: 13,
                color: _ink.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 18),
            _detailRow(
              Icons.tag_rounded,
              'Roll Number',
              '${s['rollNumber'] ?? '—'}',
            ),
            _detailRow(
              Icons.badge_outlined,
              'Student Code',
              '${s['studentCode'] ?? '—'}',
            ),
            if ('${s['email'] ?? ''}'.isNotEmpty)
              _detailRow(Icons.mail_outline_rounded, 'Email', '${s['email']}'),
            if ('${s['phone'] ?? ''}'.isNotEmpty)
              _detailRow(Icons.phone_outlined, 'Phone', '${s['phone']}'),
            if ('${s['fatherName'] ?? ''}'.isNotEmpty)
              _detailRow(
                Icons.person_outline_rounded,
                'Father',
                '${s['fatherName']}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: _purple),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: _ink.withValues(alpha: 0.5)),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final searching = _query.trim().isNotEmpty || _genderFilter != null;
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.08),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.groups_2_outlined,
              size: 42,
              color: _purple.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? 'No students found' : 'No students yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              searching
                  ? 'Try a different search or filter.'
                  : 'Students added to your class will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _ink.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _avatar(String? url) {
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

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
