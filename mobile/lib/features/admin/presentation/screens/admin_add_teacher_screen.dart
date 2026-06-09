import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../../domain/senior_stream_groups.dart';
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
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _phone = TextEditingController();
  final _subjects = TextEditingController();

  String? _classTeacherClassId;
  String? _avatarBase64;
  String _gender = 'MALE';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _loadingClasses = true;
  String? _error;
  String? _classesError;
  List<dynamic> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _phone.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final res = await ref
          .read(dioProvider)
          .get('/admin/classes')
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _classes = parseClassesResponse(res.data);
        _loadingClasses = false;
        if (_classTeacherClassId != null &&
            !_classes.any((c) => c['id'] == _classTeacherClassId)) {
          _classTeacherClassId = null;
        }
      });
      ref.invalidate(adminClassesProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _classes = [];
        _loadingClasses = false;
        _classesError = 'Could not load classes. Tap refresh to try again.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subjects = _subjects.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await ref.read(dioProvider).post('/admin/teachers', data: {
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'gender': _gender,
        'department': subjects.isNotEmpty ? subjects.first : 'General',
        'subjects': subjects,
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
    return AdminSubPageScaffold(
      title: 'Add Teacher',
      subtitle: 'Create teacher profile & assign class',
      child: SingleChildScrollView(
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
                    _passwordField(
                      label: 'Password *',
                      controller: _password,
                      hint: 'Min. 6 characters',
                      obscure: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password required';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _passwordField(
                      label: 'Confirm Password *',
                      controller: _confirmPassword,
                      hint: 'Re-enter password',
                      obscure: _obscureConfirmPassword,
                      onToggleObscure: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm password';
                        if (v != _password.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Teacher will use this email and password to log in.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
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
                    Row(
                      children: [
                        const Expanded(
                          child: AdminSectionTitle(
                            'Class Assignment',
                            icon: Icons.class_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh classes',
                          onPressed: _loadingClasses ? null : _loadClasses,
                          icon: _loadingClasses
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                    const Text(
                      'Assign this teacher as class teacher for a class (optional).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    if (_classesError != null) ...[
                      Text(
                        _classesError!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loadClasses,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ] else if (_loadingClasses)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Loading classes...',
                              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      )
                    else if (_classes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Text(
                          'No classes found. Add a class first, then come back here to assign it.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                        ),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        value: _classTeacherClassId,
                        isExpanded: true,
                        menuMaxHeight: 360,
                        decoration: InputDecoration(
                          labelText: 'Class Teacher For',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(
                            Icons.school_rounded,
                            color: Color(0xFF2D68FF),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        hint: Text('Select class (${_classes.length} available)'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No class assignment'),
                          ),
                          ..._classes.map(
                            (c) => DropdownMenuItem<String?>(
                              value: '${c['id']}',
                              child: Text(
                                classDropdownLabel(c as Map<String, dynamic>),
                                overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF2D68FF),
              size: 20,
            ),
            suffixIcon: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF9CA3AF),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }
}
