import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../widgets/admin_avatar_picker.dart';
import '../widgets/admin_sub_page.dart';

class AdminAddTeacherScreen extends ConsumerStatefulWidget {
  const AdminAddTeacherScreen({super.key});

  @override
  ConsumerState<AdminAddTeacherScreen> createState() =>
      _AdminAddTeacherScreenState();
}

class _AdminAddTeacherScreenState extends ConsumerState<AdminAddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _department = TextEditingController();
  final _subjects = TextEditingController();

  String? _classTeacherClassId;
  String? _avatarBase64;
  String _gender = 'MALE';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _department.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/admin/teachers', data: {
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'department': _department.text.trim(),
        'gender': _gender,
        'subjects': _subjects.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        if (_avatarBase64 != null) 'avatarUrl': _avatarBase64,
        if (_classTeacherClassId != null) 'classTeacherClassId': _classTeacherClassId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher added successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      setState(() => _error = msg?.toString() ?? 'Failed to add teacher');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(adminClassesProvider);

    return AdminSubPageScaffold(
      title: 'Add Teacher',
      subtitle: 'Create teacher profile & assign class',
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load classes')),
        data: (classes) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AdminPremiumCard(
                      child: Center(
                        child: AdminAvatarPicker(
                          imageBase64: _avatarBase64,
                          onChanged: (v) => setState(() => _avatarBase64 = v),
                          label: 'Capture or upload teacher photo',
                          sheetTitle: 'Teacher Photo',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Teacher Details', icon: Icons.badge_rounded),
                          AdminFormField(
                            label: 'Full Name *',
                            controller: _name,
                            hint: 'Enter teacher name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                v == null || v.trim().length < 2 ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Email *',
                            controller: _email,
                            hint: 'teacher@school.demo',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Valid email required' : null,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Phone',
                            controller: _phone,
                            hint: '+91 98765 43210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: InputDecoration(
                              labelText: 'Gender *',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: const Icon(
                                Icons.wc_rounded,
                                color: Color(0xFF2D68FF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MALE', child: Text('Gent')),
                              DropdownMenuItem(value: 'FEMALE', child: Text('Lady')),
                            ],
                            onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Department *',
                            controller: _department,
                            hint: 'Mathematics',
                            icon: Icons.apartment_rounded,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Subjects *',
                            controller: _subjects,
                            hint: 'Math, Science (comma separated)',
                            icon: Icons.menu_book_rounded,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Class Assignment', icon: Icons.class_rounded),
                          const Text(
                            'Assign this teacher as class teacher for a class (optional).',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _classTeacherClassId,
                            decoration: InputDecoration(
                              labelText: 'Class Teacher For',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: const Icon(Icons.school_rounded, color: Color(0xFF2D68FF)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            hint: const Text('Not assigned'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No class assignment'),
                              ),
                              ...classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c['id'] as String,
                                  child: Text(
                                    '${c['name']} (${c['grade']}-${c['section']})',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _classTeacherClassId = v),
                          ),
                          if (_classTeacherClassId != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF2D68FF), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This teacher will be set as the class teacher for the selected class.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    AdminPrimaryButton(
                      label: 'Save Teacher',
                      icon: Icons.check_rounded,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
