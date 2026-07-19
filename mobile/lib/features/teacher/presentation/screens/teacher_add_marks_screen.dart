import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Form for a teacher to enter marks for an exam: pick subject + exam name,
/// then enter each student's score. Saves via POST /teacher/marks.
class TeacherAddMarksScreen extends ConsumerStatefulWidget {
  const TeacherAddMarksScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAddMarksScreen> createState() =>
      _TeacherAddMarksScreenState();
}

class _TeacherAddMarksScreenState extends ConsumerState<TeacherAddMarksScreen> {
  static const _examPresets = [
    'Unit Test 1',
    'Unit Test 2',
    'Half Yearly',
    'Final Exam',
  ];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<String> _subjects = [];
  List<Map<String, dynamic>> _students = [];

  String? _subject;
  final _customSubjectCtrl = TextEditingController();
  bool _customSubject = false;
  final _examCtrl = TextEditingController(text: _examPresets.first);
  final _maxMarksCtrl = TextEditingController(text: '100');
  final Map<String, TextEditingController> _markCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customSubjectCtrl.dispose();
    _examCtrl.dispose();
    _maxMarksCtrl.dispose();
    for (final c in _markCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final subjectsRes = await dio.get(
        '/teacher/classes/${widget.classId}/subjects',
      );
      final studentsRes = await dio.get(
        '/teacher/classes/${widget.classId}/students',
        queryParameters: {'limit': 200},
      );
      final subjects = (subjectsRes.data as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList();
      final students =
          ((studentsRes.data as Map)['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subject = subjects.isNotEmpty ? subjects.first : null;
        _students = students;
        for (final s in students) {
          _markCtrls['${s['id']}'] = TextEditingController();
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load class data. Pull to retry.';
        });
      }
    }
  }

  int get _maxMarks => int.tryParse(_maxMarksCtrl.text.trim()) ?? 100;

  int get _filledCount => _markCtrls.values
      .where((c) => int.tryParse(c.text.trim()) != null)
      .length;

  Future<void> _submit() async {
    final subjectName = _customSubject
        ? _customSubjectCtrl.text.trim()
        : (_subject ?? '').trim();
    final examName = _examCtrl.text.trim();
    final maxMarks = _maxMarks;

    if (subjectName.isEmpty) {
      setState(() => _error = 'Select or enter a subject');
      return;
    }
    if (examName.isEmpty) {
      setState(() => _error = 'Enter an exam name');
      return;
    }
    if (maxMarks <= 0) {
      setState(() => _error = 'Max marks must be greater than 0');
      return;
    }

    final entries = <Map<String, dynamic>>[];
    for (final s in _students) {
      final id = '${s['id']}';
      final raw = _markCtrls[id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final val = int.tryParse(raw);
      if (val == null) continue;
      entries.add({'studentId': id, 'marks': val.clamp(0, maxMarks)});
    }

    if (entries.isEmpty) {
      setState(() => _error = "Enter at least one student's marks");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(dioProvider)
          .post(
            '/teacher/marks',
            data: {
              'classId': widget.classId,
              'subjectName': subjectName,
              'termLabel': examName,
              'maxMarks': maxMarks,
              'entries': entries,
            },
          );
      if (!mounted) return;
      final saved = (res.data as Map)['saved'] ?? entries.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved marks for $saved student${saved == 1 ? '' : 's'}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.teacherPrimary,
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ?? 'Could not save marks';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not save marks';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Add Marks', widget.classLabel),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teacherPrimary),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      teacherFieldLabel('Subject *'),
                      _subjectField(),
                      const SizedBox(height: 14),
                      teacherFieldLabel('Exam name *'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in _examPresets) _examChip(preset),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _examCtrl,
                        decoration: teacherInputDecoration(
                          hint: 'e.g. Midterm Exam',
                          icon: Icons.edit_note_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      teacherFieldLabel('Max marks *'),
                      TextField(
                        controller: _maxMarksCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: teacherInputDecoration(
                          hint: '100',
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            'Students',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teacherPrimary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_filledCount/${_students.length} entered',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.teacherPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_students.isEmpty)
                        reportEmptyState(
                          icon: Icons.groups_outlined,
                          searching: false,
                          text:
                              'Add students to this class before entering marks.',
                        )
                      else
                        ..._students.map(_studentMarkRow),
                    ],
                  ),
                ),
                _bottomBar(),
              ],
            ),
    );
  }

  Widget _subjectField() {
    if (_customSubject || _subjects.isEmpty) {
      return TextField(
        controller: _customSubjectCtrl,
        decoration: teacherInputDecoration(
          hint: 'Enter subject name',
          icon: Icons.menu_book_rounded,
          suffixIcon: _subjects.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.list_rounded,
                    color: AppColors.teacherPrimary,
                  ),
                  onPressed: () => setState(() => _customSubject = false),
                ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _subject,
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          items: [
            for (final s in _subjects)
              DropdownMenuItem(value: s, child: Text(s)),
            const DropdownMenuItem(
              value: '__custom__',
              child: Text('+ Add new subject'),
            ),
          ],
          onChanged: (v) {
            if (v == '__custom__') {
              setState(() => _customSubject = true);
            } else {
              setState(() => _subject = v);
            }
          },
        ),
      ),
    );
  }

  Widget _examChip(String label) {
    final selected = _examCtrl.text.trim() == label;
    return GestureDetector(
      onTap: () => setState(() => _examCtrl.text = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [teacherHeaderStart, teacherHeaderEnd],
                )
              : null,
          color: selected ? null : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _studentMarkRow(Map<String, dynamic> s) {
    final id = '${s['id']}';
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final ctrl = _markCtrls[id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: teacherCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teacherPrimary.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.teacherPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  'Roll $roll',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                suffixText: '/$_maxMarks',
                suffixStyle: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FC),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.teacherPrimary),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: teacherBg,
        border: const Border(top: BorderSide(color: Color(0xFFEDEFF5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
            ],
            teacherPrimaryButton(
              label: 'Save Marks',
              loading: _saving,
              onTap: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
