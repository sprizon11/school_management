import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../widgets/admin_avatar_picker.dart';
import '../widgets/admin_sub_page.dart';

class AdminEditStudentScreen extends ConsumerStatefulWidget {
  const AdminEditStudentScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<AdminEditStudentScreen> createState() =>
      _AdminEditStudentScreenState();
}

class _AdminEditStudentScreenState
    extends ConsumerState<AdminEditStudentScreen> {
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
  String _status = 'ACTIVE';
  String? _bloodGroup;
  DateTime? _dob;
  String? _avatarBase64;
  bool _loading = false;
  bool _initializing = true;
  String? _error;

  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _roll,
      _address,
      _fatherName,
      _fatherPhone,
      _fatherOccupation,
      _motherName,
      _motherPhone,
      _motherOccupation,
      _parentAddress,
      _emergencyContact,
      _emergencyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudent() async {
    try {
      final res = await ref
          .read(dioProvider)
          .get('/admin/students/${widget.studentId}');
      final s = res.data as Map<String, dynamic>;
      _name.text = '${s['fullName'] ?? ''}';
      _email.text = '${s['email'] ?? ''}';
      _phone.text = '${s['phone'] ?? ''}';
      _roll.text = s['rollNumber'] != null ? '${s['rollNumber']}' : '';
      _address.text = '${s['address'] ?? ''}';
      _fatherName.text = '${s['fatherName'] ?? ''}';
      _fatherPhone.text = '${s['fatherPhone'] ?? ''}';
      _fatherOccupation.text = '${s['fatherOccupation'] ?? ''}';
      _motherName.text = '${s['motherName'] ?? ''}';
      _motherPhone.text = '${s['motherPhone'] ?? ''}';
      _motherOccupation.text = '${s['motherOccupation'] ?? ''}';
      _parentAddress.text = '${s['parentAddress'] ?? ''}';
      _emergencyContact.text = '${s['emergencyContact'] ?? ''}';
      _emergencyPhone.text = '${s['emergencyPhone'] ?? ''}';
      final avatar = s['avatarUrl'] as String?;
      setState(() {
        _classId = s['classId'] as String?;
        _gender = '${s['gender'] ?? 'MALE'}';
        _status = '${s['status'] ?? 'ACTIVE'}';
        _bloodGroup = s['bloodGroup'] as String?;
        _dob = s['dateOfBirth'] != null
            ? DateTime.tryParse('${s['dateOfBirth']}')
            : null;
        _avatarBase64 = avatar != null && avatar.startsWith('data:image')
            ? avatar
            : null;
        _initializing = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load student';
        _initializing = false;
      });
    }
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

  Map<String, dynamic> _buildPayload() {
    return {
      'fullName': _name.text.trim(),
      'gender': _gender,
      'classId': _classId,
      'status': _status,
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      if (_roll.text.trim().isNotEmpty)
        'rollNumber': int.parse(_roll.text.trim()),
      if (_dob != null) 'dateOfBirth': DateFormat('yyyy-MM-dd').format(_dob!),
      'bloodGroup': _bloodGroup ?? '',
      'address': _address.text.trim(),
      if (_avatarBase64 != null) 'avatarUrl': _avatarBase64,
      'fatherName': _fatherName.text.trim(),
      'fatherPhone': _fatherPhone.text.trim(),
      'fatherOccupation': _fatherOccupation.text.trim(),
      'motherName': _motherName.text.trim(),
      'motherPhone': _motherPhone.text.trim(),
      'motherOccupation': _motherOccupation.text.trim(),
      'parentAddress': _parentAddress.text.trim(),
      'emergencyContact': _emergencyContact.text.trim(),
      'emergencyPhone': _emergencyPhone.text.trim(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _classId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(dioProvider)
          .patch('/admin/students/${widget.studentId}', data: _buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      setState(() => _error = msg?.toString() ?? 'Failed to update student');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final classesAsync = ref.watch(adminClassesProvider);

    return AdminSubPageScaffold(
      title: 'Edit Student',
      subtitle: 'Update student & parent details',
      child: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load classes')),
        data: (classes) {
          final selectedClassId =
              _classId ??
              (classes.isNotEmpty ? '${classes.first['id']}' : null);
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
                        label: 'Change student photo',
                        sheetTitle: 'Student Photo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AdminPremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionTitle(
                          'Student Details',
                          icon: Icons.school_rounded,
                        ),
                        AdminFormField(
                          label: 'Full Name *',
                          controller: _name,
                          hint: 'Enter student full name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _dropdownField(
                                label: 'Gender *',
                                value: _gender,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'MALE',
                                    child: Text('Male'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'FEMALE',
                                    child: Text('Female'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _gender = v ?? 'MALE'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dropdownField(
                                label: 'Status',
                                value: _status,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'ACTIVE',
                                    child: Text('Active'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'INACTIVE',
                                    child: Text('Inactive'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _status = v ?? 'ACTIVE'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _dropdownField(
                          label: 'Blood Group',
                          value: _bloodGroup,
                          hint: 'Select',
                          items: _bloodGroups
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _bloodGroup = v),
                        ),
                        const SizedBox(height: 14),
                        _dateField(),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Email',
                          controller: _email,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Phone',
                          controller: _phone,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Roll Number',
                          controller: _roll,
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
                                  value: '${c['id']}',
                                  child: Text(
                                    '${c['name']} (${c['grade']}-${c['section']})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Home Address',
                          controller: _address,
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
                        const AdminSectionTitle(
                          'Father Details',
                          icon: Icons.man_rounded,
                        ),
                        AdminFormField(
                          label: 'Father Name',
                          controller: _fatherName,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Father Phone',
                          controller: _fatherPhone,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Father Occupation',
                          controller: _fatherOccupation,
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
                        const AdminSectionTitle(
                          'Mother Details',
                          icon: Icons.woman_rounded,
                        ),
                        AdminFormField(
                          label: 'Mother Name',
                          controller: _motherName,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Mother Phone',
                          controller: _motherPhone,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Mother Occupation',
                          controller: _motherOccupation,
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
                        const AdminSectionTitle(
                          'Guardian & Emergency',
                          icon: Icons.family_restroom_rounded,
                        ),
                        AdminFormField(
                          label: 'Parent / Guardian Address',
                          controller: _parentAddress,
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Emergency Contact Name',
                          controller: _emergencyContact,
                          icon: Icons.contact_emergency_outlined,
                        ),
                        const SizedBox(height: 14),
                        AdminFormField(
                          label: 'Emergency Phone',
                          controller: _emergencyPhone,
                          icon: Icons.phone_in_talk_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  AdminPrimaryButton(
                    label: 'Save Changes',
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

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
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
                const Icon(
                  Icons.cake_outlined,
                  color: Color(0xFF2D68FF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _dob == null
                      ? 'Select date of birth'
                      : DateFormat('dd MMM yyyy').format(_dob!),
                  style: TextStyle(
                    fontSize: 14,
                    color: _dob == null
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF111827),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
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
