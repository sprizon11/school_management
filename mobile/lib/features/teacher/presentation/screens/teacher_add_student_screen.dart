import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/widgets/admin_avatar_picker.dart';
import '../../../admin/presentation/widgets/admin_sub_page.dart';

class TeacherAddStudentScreen extends ConsumerStatefulWidget {
  const TeacherAddStudentScreen({
    super.key,
    required this.classId,
    required this.classLabel,
  });

  final String classId;
  final String classLabel;

  @override
  ConsumerState<TeacherAddStudentScreen> createState() =>
      _TeacherAddStudentScreenState();
}

class _TeacherAddStudentScreenState
    extends ConsumerState<TeacherAddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _roll = TextEditingController();
  final _fatherName = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherName = TextEditingController();
  final _motherPhone = TextEditingController();
  String _gender = 'MALE';
  DateTime? _dob;
  String? _avatarBase64;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _roll,
      _fatherName,
      _fatherPhone,
      _motherName,
      _motherPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2012, 1, 1),
      firstDate: DateTime(1995),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(dioProvider)
          .post(
            '/teacher/students',
            data: {
              'fullName': _name.text.trim(),
              'gender': _gender,
              'classId': widget.classId,
              if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
              if (_roll.text.trim().isNotEmpty)
                'rollNumber': int.parse(_roll.text.trim()),
              if (_dob != null)
                'dateOfBirth': DateFormat('yyyy-MM-dd').format(_dob!),
              if (_avatarBase64 != null) 'avatarUrl': _avatarBase64,
              if (_fatherName.text.trim().isNotEmpty)
                'fatherName': _fatherName.text.trim(),
              if (_fatherPhone.text.trim().isNotEmpty)
                'fatherPhone': _fatherPhone.text.trim(),
              if (_motherName.text.trim().isNotEmpty)
                'motherName': _motherName.text.trim(),
              if (_motherPhone.text.trim().isNotEmpty)
                'motherPhone': _motherPhone.text.trim(),
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added. Parent can log in with Parent@123'),
        ),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ?? 'Could not add student';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not add student';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubPageScaffold(
      title: 'Add Student',
      subtitle: 'Class ${widget.classLabel}',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: AdminAvatarPicker(
                imageBase64: _avatarBase64,
                onChanged: (v) => setState(() => _avatarBase64 = v),
              ),
            ),
            const SizedBox(height: 16),
            AdminFormField(
              label: 'Full name *',
              controller: _name,
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender *'),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
            ),
            const SizedBox(height: 12),
            AdminFormField(
              label: 'Phone',
              controller: _phone,
              icon: Icons.phone_outlined,
            ),
            AdminFormField(
              label: 'Roll number',
              controller: _roll,
              icon: Icons.tag,
              keyboardType: TextInputType.number,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dob == null
                    ? 'Date of birth'
                    : DateFormat('d MMM yyyy').format(_dob!),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDob,
            ),
            const SizedBox(height: 8),
            const Text(
              'Parent details',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            AdminFormField(
              label: 'Father name',
              controller: _fatherName,
              icon: Icons.man_outlined,
            ),
            AdminFormField(
              label: 'Father phone',
              controller: _fatherPhone,
              icon: Icons.phone_outlined,
            ),
            AdminFormField(
              label: 'Mother name',
              controller: _motherName,
              icon: Icons.woman_outlined,
            ),
            AdminFormField(
              label: 'Mother phone',
              controller: _motherPhone,
              icon: Icons.phone_outlined,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teacherPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Student'),
            ),
          ],
        ),
      ),
    );
  }
}
