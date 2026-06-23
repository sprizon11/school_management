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
  ConsumerState<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  List<dynamic> _classes = [];
  String? _classId;
  List<dynamic> _students = [];
  Map<String, dynamic>? _classInfo;
  bool _loading = true;
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
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final detail = await dio.get('/teacher/classes/$classId');
      final roster = await dio.get(
        '/teacher/classes/$classId/students',
        queryParameters: {
          'limit': 100,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
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
    final boys = _students.where((s) => '${(s as Map)['gender']}' == 'MALE').length;
    final girls = _students.length - boys;

    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          TeacherPageHeader(
            title: 'Students',
            subtitle: '${_classes.length} class${_classes.length == 1 ? '' : 'es'} assigned',
            bottomChild: _classes.length > 1
                ? SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _classes.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = _classes[i] as Map<String, dynamic>;
                        final id = '${c['id']}';
                        final selected = id == _classId;
                        return FilterChip(
                          label: Text('${c['grade']}${c['section']}'),
                          selected: selected,
                          onSelected: (_) => _loadStudents(id),
                          selectedColor: Colors.white,
                          checkmarkColor: AppColors.teacherPrimary,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? AppColors.teacherPrimary : Colors.white,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          side: BorderSide(
                            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          ),
                        );
                      },
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: Stack(
                children: [
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary))
                      : RefreshIndicator(
                          onRefresh: () => _classId != null ? _loadStudents(_classId!) : _loadClasses(),
                          color: AppColors.teacherPrimary,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            children: [
                              if (_classInfo != null) ...[
                                Row(
                                  children: [
                                    _statChip('Total', '$studentCount', AppColors.teacherPrimary),
                                    const SizedBox(width: 8),
                                    _statChip('Boys', '$boys', const Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    _statChip('Girls', '$girls', const Color(0xFFDB2777)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _search,
                                  decoration: InputDecoration(
                                    hintText: 'Search students...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    if (_classId != null) _loadStudents(_classId!);
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_students.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: teacherCardDecoration(),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                                      const SizedBox(height: 12),
                                      Text(
                                        _isClassTeacher
                                            ? 'No students yet. Tap + to add.'
                                            : 'No students in this class.',
                                        style: const TextStyle(color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._students.map((raw) => _studentTile(raw as Map<String, dynamic>)),
                            ],
                          ),
                        ),
                  if (_isClassTeacher && !_loading)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.extended(
                        onPressed: _openAddStudent,
                        backgroundColor: AppColors.teacherPrimary,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Student'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: teacherCardDecoration(),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _studentTile(Map<String, dynamic> st) {
    final gender = '${st['gender'] ?? ''}';
    final isFemale = gender == 'FEMALE';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: teacherCardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isFemale ? const Color(0xFFFCE7F3) : const Color(0xFFDBEAFE),
          child: Text(
            '${st['fullName'] ?? '?'}'[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB),
            ),
          ),
        ),
        title: Text('${st['fullName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          'Roll ${st['rollNumber'] ?? '—'} · ${st['studentCode'] ?? ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isFemale ? const Color(0xFFFCE7F3) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isFemale ? 'Female' : 'Male',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isFemale ? const Color(0xFFDB2777) : const Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }
}
