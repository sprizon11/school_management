import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';
import 'teacher_add_student_screen.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  List<dynamic> _classes = [];
  String? _classId;
  List<dynamic> _students = [];
  Map<String, dynamic>? _classInfo;
  bool _loading = true;
  String _query = '';
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
    });
    try {
      final dio = ref.read(dioProvider);
      final detail = await dio.get('/teacher/classes/$classId');
      final roster = await dio.get(
        '/teacher/classes/$classId/students',
        queryParameters: {'limit': 100},
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
    final list =
        _students.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (q.isEmpty) return list;
    return list.where((s) {
      final name = '${s['fullName'] ?? ''}'.toLowerCase();
      final roll = '${s['rollNumber'] ?? ''}'.toLowerCase();
      final code = '${s['studentCode'] ?? ''}'.toLowerCase();
      return name.contains(q) || roll.contains(q) || code.contains(q);
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final studentCount = _classInfo?['_count']?['students'] ?? _students.length;
    final boys =
        _students.where((s) => '${(s as Map)['gender']}' == 'MALE').length;
    final girls = _students.length - boys;
    final filtered = _filtered;

    return ColoredBox(
      color: teacherBg,
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.teacherPrimary),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _classId != null
                            ? _loadStudents(_classId!)
                            : _loadClasses(),
                        color: AppColors.teacherPrimary,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          children: [
                            Row(
                              children: [
                                _statCard('Total', '$studentCount',
                                    AppColors.teacherPrimary, Icons.groups_rounded),
                                const SizedBox(width: 10),
                                _statCard('Boys', '$boys',
                                    const Color(0xFF2563EB), Icons.male_rounded),
                                const SizedBox(width: 10),
                                _statCard('Girls', '$girls',
                                    const Color(0xFFDB2777), Icons.female_rounded),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_students.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    _query.isEmpty
                                        ? 'All Students'
                                        : 'Results',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.teacherPrimary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${filtered.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.teacherPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_students.isEmpty)
                              _emptyState(isSearch: false)
                            else if (filtered.isEmpty)
                              _emptyState(isSearch: true)
                            else
                              ...filtered.asMap().entries.map(
                                    (e) => _studentTile(e.value, e.key),
                                  ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (_isClassTeacher && !_loading && _students.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 24,
              child: _addFab(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header — plain style (matches Reports)
  // ---------------------------------------------------------------------
  Widget _buildHeader() {
    final multiClass = _classes.length > 1;

    return TeacherPlainHeader(
      icon: Icons.groups_rounded,
      title: 'Students',
      subtitle: _classInfo != null
          ? 'Class ${_classInfo!['grade']}${_classInfo!['section']}'
              '${multiClass ? ' · ${_classes.length} classes' : ''}'
          : '${_classes.length} class${_classes.length == 1 ? '' : 'es'} assigned',
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (multiClass) ...[
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _classes.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _classes[i] as Map<String, dynamic>;
                  final id = '${c['id']}';
                  final selected = id == _classId;
                  return GestureDetector(
                    onTap: () => _loadStudents(id),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [teacherHeaderStart, teacherHeaderEnd],
                              )
                            : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: Text(
                        '${c['grade']}${c['section']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          TeacherSearchField(
            hint: 'Search by name, roll or code',
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            showClear: _query.isNotEmpty,
            onClear: () {
              _search.clear();
              setState(() => _query = '');
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Stat card
  // ---------------------------------------------------------------------
  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF111827),
                    height: 1,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
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
  // Student tile
  // ---------------------------------------------------------------------
  Widget _studentTile(Map<String, dynamic> st, int index) {
    final gender = '${st['gender'] ?? ''}';
    final isFemale = gender == 'FEMALE';
    final color =
        isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
    final name = '${st['fullName'] ?? '?'}';
    final roll = '${st['rollNumber'] ?? '—'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: teacherCardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(teacherCardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(teacherCardRadius),
          onTap: () => _showStudentSheet(st),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.18)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _miniTag('Roll $roll',
                              const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
                          if ('${st['studentCode'] ?? ''}'.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${st['studentCode']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(isFemale ? Icons.female_rounded : Icons.male_rounded,
                          size: 12, color: color),
                      const SizedBox(width: 3),
                      Text(
                        isFemale ? 'Girl' : 'Boy',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Student detail bottom sheet
  // ---------------------------------------------------------------------
  void _showStudentSheet(Map<String, dynamic> st) {
    final gender = '${st['gender'] ?? ''}';
    final isFemale = gender == 'FEMALE';
    final color =
        isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB);
    final name = '${st['fullName'] ?? '?'}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
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
            const SizedBox(height: 18),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Class ${_classInfo?['grade'] ?? ''}${_classInfo?['section'] ?? ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            _detailRow(Icons.tag_rounded, 'Roll Number',
                '${st['rollNumber'] ?? '—'}'),
            _detailRow(Icons.badge_outlined, 'Student Code',
                '${st['studentCode'] ?? '—'}'),
            _detailRow(isFemale ? Icons.female_rounded : Icons.male_rounded,
                'Gender', isFemale ? 'Female' : 'Male'),
            if ('${st['fatherName'] ?? ''}'.isNotEmpty)
              _detailRow(Icons.person_outline_rounded, 'Father',
                  '${st['fatherName']}'),
            if ('${st['motherName'] ?? ''}'.isNotEmpty)
              _detailRow(Icons.person_outline_rounded, 'Mother',
                  '${st['motherName']}'),
            if ('${st['phone'] ?? ''}'.isNotEmpty)
              _detailRow(Icons.phone_outlined, 'Phone', '${st['phone']}'),
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
              color: AppColors.teacherPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.teacherPrimary),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Empty state + FAB
  // ---------------------------------------------------------------------
  Widget _emptyState({required bool isSearch}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teacherPrimary.withValues(alpha: 0.08),
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.groups_2_outlined,
              size: 42,
              color: AppColors.teacherPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isSearch ? 'No students found' : 'No students yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isSearch
                  ? 'Try a different name, roll number or code.'
                  : _isClassTeacher
                      ? 'Add your first student to start building the class roster.'
                      : 'Students added by the class teacher will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (!isSearch && _isClassTeacher) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openAddStudent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [teacherHeaderStart, teacherHeaderEnd],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.teacherPrimary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Add Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addFab() {
    return GestureDetector(
      onTap: _openAddStudent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [teacherHeaderStart, teacherHeaderEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.teacherPrimary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Student',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
