import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

/// Form for a teacher to assign new homework/an assignment to their class.
class TeacherAddAssignmentScreen extends ConsumerStatefulWidget {
  const TeacherAddAssignmentScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAddAssignmentScreen> createState() =>
      _TeacherAddAssignmentScreenState();
}

class _TeacherAddAssignmentScreenState
    extends ConsumerState<TeacherAddAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.teacherPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/teacher/homework', data: {
        'classId': widget.classId,
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'dueDate': DateFormat('yyyy-MM-dd').format(_dueDate),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment added'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.teacherPrimary,
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ?? 'Could not save assignment';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not save assignment';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teacherBg,
      appBar: reportAppBar('Add Assignment', widget.classLabel),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            teacherFieldLabel('Title *'),
            TextFormField(
              controller: _title,
              decoration: teacherInputDecoration(
                hint: 'e.g. Chapter 4 worksheet',
                icon: Icons.assignment_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            teacherFieldLabel('Description'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: teacherInputDecoration(
                hint: 'Optional instructions for students',
                icon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 14),
            teacherFieldLabel('Due date *'),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDueDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        size: 19, color: AppColors.teacherPrimary),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('EEEE, d MMM yyyy').format(_dueDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 24),
            teacherPrimaryButton(
              label: 'Save Assignment',
              loading: _saving,
              onTap: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
