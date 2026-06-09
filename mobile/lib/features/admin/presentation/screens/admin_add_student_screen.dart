import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../widgets/admin_avatar_picker.dart';
import '../widgets/admin_sub_page.dart';
import 'admin_add_class_screen.dart';

class AdminAddStudentScreen extends ConsumerStatefulWidget {
  const AdminAddStudentScreen({
    super.key,
    this.flowStep,
    this.flowTotal,
    this.onAddAnotherClass,
  });

  final int? flowStep;
  final int? flowTotal;
  final VoidCallback? onAddAnotherClass;

  @override
  ConsumerState<AdminAddStudentScreen> createState() =>
      _AdminAddStudentScreenState();
}

class _AdminAddStudentScreenState extends ConsumerState<AdminAddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _roll = TextEditingController();
  final _address = TextEditingController();
  final _fatherName = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _fatherOccupation = TextEditingController();
  final _motherName = TextEditingController();
  final _motherPhone = TextEditingController();
  final _motherOccupation = TextEditingController();
  final _parentAddress = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  String? _classId;
  String _gender = 'MALE';
  String? _bloodGroup;
  DateTime? _dob;
  String? _avatarBase64;
  bool _loading = false;
  String? _error;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _roll, _address,
      _fatherName, _fatherPhone, _fatherOccupation,
      _motherName, _motherPhone, _motherOccupation,
      _parentAddress, _emergencyContact, _emergencyPhone,
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

  Map<String, dynamic> _buildPayload(String classId) {
    return {
      'fullName': _name.text.trim(),
      'gender': _gender,
      'classId': classId,
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_roll.text.trim().isNotEmpty) 'rollNumber': int.parse(_roll.text.trim()),
      if (_dob != null) 'dateOfBirth': DateFormat('yyyy-MM-dd').format(_dob!),
      if (_bloodGroup != null) 'bloodGroup': _bloodGroup,
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_avatarBase64 != null) 'avatarUrl': _avatarBase64,
      if (_fatherName.text.trim().isNotEmpty) 'fatherName': _fatherName.text.trim(),
      if (_fatherPhone.text.trim().isNotEmpty) 'fatherPhone': _fatherPhone.text.trim(),
      if (_fatherOccupation.text.trim().isNotEmpty) 'fatherOccupation': _fatherOccupation.text.trim(),
      if (_motherName.text.trim().isNotEmpty) 'motherName': _motherName.text.trim(),
      if (_motherPhone.text.trim().isNotEmpty) 'motherPhone': _motherPhone.text.trim(),
      if (_motherOccupation.text.trim().isNotEmpty) 'motherOccupation': _motherOccupation.text.trim(),
      if (_parentAddress.text.trim().isNotEmpty) 'parentAddress': _parentAddress.text.trim(),
      if (_emergencyContact.text.trim().isNotEmpty) 'emergencyContact': _emergencyContact.text.trim(),
      if (_emergencyPhone.text.trim().isNotEmpty) 'emergencyPhone': _emergencyPhone.text.trim(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cached = ref.read(adminClassesProvider).valueOrNull;
    final classId = _classId ??
        (cached != null && cached.isNotEmpty ? cached.first['id'] as String : null);
    if (classId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/admin/students', data: _buildPayload(classId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      setState(() => _error = msg?.toString() ?? 'Failed to add student');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(adminClassesProvider);

    final stepLabel = widget.flowStep != null && widget.flowTotal != null
        ? 'Step ${widget.flowStep} of ${widget.flowTotal} · '
        : '';

    return AdminSubPageScaffold(
      title: 'Add Student',
      subtitle: '$stepLabel Complete student & parent profile',
      actions: widget.onAddAnotherClass != null
          ? [
              TextButton(
                onPressed: widget.onAddAnotherClass,
                child: const Text(
                  'Add class',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ]
          : null,
      child: classesAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                'Loading classes...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(adminClassesProvider),
                child: const Text('Taking too long? Tap to retry'),
              ),
            ],
          ),
        ),
        error: (_, __) => _noClassPrompt(retry: () => ref.invalidate(adminClassesProvider)),
        data: (classes) {
          if (classes.isEmpty) {
            return _noClassPrompt(
              retry: () => ref.invalidate(adminClassesProvider),
            );
          }
          final selectedClassId = _classId ??
              (classes.isNotEmpty ? classes.first['id'] as String : null);
          return SingleChildScrollView(
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
                          label: 'Capture or upload student photo',
                          sheetTitle: 'Student Photo',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Student Details', icon: Icons.school_rounded),
                          AdminFormField(
                            label: 'Full Name *',
                            controller: _name,
                            hint: 'Enter student full name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                v == null || v.trim().length < 2 ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _dropdownField(
                                  label: 'Gender *',
                                  value: _gender,
                                  items: const [
                                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                                  ],
                                  onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _dropdownField(
                                  label: 'Blood Group',
                                  value: _bloodGroup,
                                  hint: 'Select',
                                  items: _bloodGroups
                                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _bloodGroup = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _dateField(),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Email',
                            controller: _email,
                            hint: 'student@school.demo',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
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
                          AdminFormField(
                            label: 'Roll Number',
                            controller: _roll,
                            hint: 'Auto-assigned if empty',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          _dropdownField(
                            label: 'Class *',
                            value: selectedClassId,
                            items: classes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text('${c['name']} (${c['grade']}-${c['section']})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _classId = v),
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Home Address',
                            controller: _address,
                            hint: 'House no, street, city, pin code',
                            icon: Icons.home_outlined,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Father Details', icon: Icons.man_rounded),
                          AdminFormField(
                            label: 'Father Name',
                            controller: _fatherName,
                            hint: 'Full name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Father Phone',
                            controller: _fatherPhone,
                            hint: '+91 98765 43210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Father Occupation',
                            controller: _fatherOccupation,
                            hint: 'Job / business',
                            icon: Icons.work_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Mother Details', icon: Icons.woman_rounded),
                          AdminFormField(
                            label: 'Mother Name',
                            controller: _motherName,
                            hint: 'Full name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Mother Phone',
                            controller: _motherPhone,
                            hint: '+91 98765 43210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Mother Occupation',
                            controller: _motherOccupation,
                            hint: 'Job / business',
                            icon: Icons.work_outline_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AdminPremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AdminSectionTitle('Guardian & Emergency', icon: Icons.family_restroom_rounded),
                          AdminFormField(
                            label: 'Parent / Guardian Address',
                            controller: _parentAddress,
                            hint: 'If different from student address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Emergency Contact Name',
                            controller: _emergencyContact,
                            hint: 'Contact person name',
                            icon: Icons.contact_emergency_outlined,
                          ),
                          const SizedBox(height: 14),
                          AdminFormField(
                            label: 'Emergency Phone',
                            controller: _emergencyPhone,
                            hint: '+91 98765 43210',
                            icon: Icons.phone_in_talk_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    AdminPrimaryButton(
                      label: 'Save Student',
                      icon: Icons.check_rounded,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
        },
      ),
    );
  }

  Widget _noClassPrompt({VoidCallback? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 40,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No class found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a class first, then you can add students to it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  SmoothPageRoute(page: const AdminAddClassScreen()),
                );
                if (created == true) {
                  ref.invalidate(adminClassesProvider);
                  retry?.call();
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Class'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDob,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Color(0xFF2D68FF), size: 20),
                const SizedBox(width: 10),
                Text(
                  _dob == null
                      ? 'Select date of birth'
                      : DateFormat('dd MMM yyyy').format(_dob!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _dob == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? hint,
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
        DropdownButtonFormField<String>(
          value: value,
          hint: hint != null ? Text(hint) : null,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
