import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/providers/auth_provider.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_add_student_screen.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  static const _hPad = 16.0;
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF635BFF);

  List<dynamic> _classes = [];
  String? _classId;
  List<dynamic> _students = [];
  Map<String, dynamic>? _classInfo;
  bool _loading = true;
  String _query = '';
  String? _genderFilter;
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
    final visible = _filtered;
    final total = _students.length;
    final active = _students
        .where((s) => '${(s as Map)['status']}' == 'ACTIVE')
        .length;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 96;

    // Same shape as the admin Students screen: fixed header, then stats /
    // search / list header above one continuous scrolling roster.
    final body = ColoredBox(
      color: const Color(0xFFF4F6FA),
      child: Column(
        children: [
          _header(),
          Expanded(
            child: _loading
                ? _loadingSkeleton()
                : Column(
                    children: [
                      const SizedBox(height: 14),
                      EntranceFade(child: _statsRow(total, active)),
                      const SizedBox(height: 12),
                      EntranceFade(
                        delay: const Duration(milliseconds: 60),
                        child: _searchField(),
                      ),
                      const SizedBox(height: 10),
                      EntranceFade(
                        delay: const Duration(milliseconds: 100),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _hPad),
                          child: _classFilterRow(),
                        ),
                      ),
                      _listHeader(visible.length),
                      Expanded(
                        child: RefreshIndicator(
                          color: _purple,
                          onRefresh: () => _classId != null
                              ? _loadStudents(_classId!)
                              : _loadClasses(),
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
                                      visible[i],
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
        ],
      ),
    );

    // Add sits in a floating "+" clear of the nav bar, matching the admin
    // Students screen — the header only carries the title and the menu.
    if (!_isClassTeacher) return body;
    return TeacherFabScaffold(
      fab: TeacherFab(
        icon: Icons.add_rounded,
        tooltip: 'Add student',
        onTap: _openAddStudent,
      ),
      child: body,
    );
  }

  Widget _loadingSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Mirrors the real layout — stats, search, filters — so nothing
          // jumps when the roster lands.
          SkeletonBox(height: 52, borderRadius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 48, borderRadius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 54, borderRadius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 300, borderRadius: 18),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _header() {
    return const TeacherPlainHeader(
      title: 'Students',
      subtitle: 'Manage and view your students',
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
              // No autofocus: the field is always on screen now, so grabbing
              // focus would pop the keyboard every time the tab is opened.
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 13.5),
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() {
                  _query = v;
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
            // Clearing used to happen when the search toggle closed; with the
            // field permanent it needs its own control.
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _query = '';
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
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

  /// Class picker only. Gender filtering lives on the Total / Boys / Girls
  /// stat cards above, so a separate filter control would be a second way to
  /// set the same thing.
  Widget _classFilterRow() {
    return _pill(
      Icons.school_rounded,
      'Class',
      _classInfo != null
          ? 'Class ${_classInfo!['grade']} - ${_classInfo!['section']}'
          : 'Select',
      onTap: _classes.length > 1 ? _showClassSheet : null,
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

  // ---------------------------------------------------------------------
  Widget _studentRow(
    Map<String, dynamic> s, {
    required bool first,
    required bool last,
  }) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final email = '${s['email'] ?? ''}';
    final phone = '${s['phone'] ?? ''}';
    final code = '${s['studentCode'] ?? ''}';
    final line2 = email.isNotEmpty ? email : code;
    final gender = '${s['gender']}';
    final isFemale = gender == 'FEMALE';
    final tint = isFemale ? const Color(0xFFEC4899) : const Color(0xFF3B82F6);
    final isActive = '${s['status']}' == 'ACTIVE';
    final avatar = _avatar(s['avatarUrl'] as String?);

    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(18) : Radius.zero,
      bottom: last ? const Radius.circular(18) : Radius.zero,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFF0F1F6)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStudentSheet(s),
          borderRadius: radius,
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
                        name,
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
                // Admin puts the class here; inside a single class roster that
                // would repeat on every row, so the roll number takes the slot.
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
                        'Roll No. ${roll.padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF9CA3AF),
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
    final filtered = _query.trim().isNotEmpty || _genderFilter != null;
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
                : 'Students added to your class will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _ink.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          if (filtered)
            OutlinedButton.icon(
              onPressed: () {
                _search.clear();
                FocusScope.of(context).unfocus();
                setState(() {
                  _query = '';
                  _genderFilter = null;
                });
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
