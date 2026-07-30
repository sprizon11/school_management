import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../../../admin/presentation/widgets/admin_avatar_picker.dart';

/// Full-page student profile for teachers — view every detail, edit them, and
/// upload a photo. Backed by GET/PATCH /teacher/students/:id.
class TeacherStudentDetailScreen extends ConsumerStatefulWidget {
  const TeacherStudentDetailScreen({
    super.key,
    required this.studentId,
    this.initial,
  });

  final String studentId;
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends ConsumerState<TeacherStudentDetailScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = AppColors.teacherPrimary;

  Map<String, dynamic> _s = {};
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  bool _changed = false;

  // Edit controllers.
  final _name = TextEditingController();
  final _roll = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
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
  String _gender = 'MALE';
  String _status = 'ACTIVE';
  String? _bloodGroup;
  DateTime? _dob;
  String? _avatarBase64;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _s = Map<String, dynamic>.from(widget.initial!);
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _roll, _email, _phone, _address,
      _fatherName, _fatherPhone, _fatherOccupation,
      _motherName, _motherPhone, _motherOccupation,
      _parentAddress, _emergencyContact, _emergencyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref
          .read(dioProvider)
          .get('/teacher/students/${widget.studentId}');
      if (!mounted) return;
      setState(() {
        _s = Map<String, dynamic>.from(res.data as Map);
        _loading = false;
      });
    } catch (_) {
      if (mounted && _s.isEmpty) setState(() => _loading = false);
    }
  }

  void _enterEdit() {
    _name.text = '${_s['fullName'] ?? ''}';
    _roll.text = '${_s['rollNumber'] ?? ''}';
    _email.text = '${_s['email'] ?? ''}';
    _phone.text = '${_s['phone'] ?? ''}';
    _address.text = '${_s['address'] ?? ''}';
    _fatherName.text = '${_s['fatherName'] ?? ''}';
    _fatherPhone.text = '${_s['fatherPhone'] ?? ''}';
    _fatherOccupation.text = '${_s['fatherOccupation'] ?? ''}';
    _motherName.text = '${_s['motherName'] ?? ''}';
    _motherPhone.text = '${_s['motherPhone'] ?? ''}';
    _motherOccupation.text = '${_s['motherOccupation'] ?? ''}';
    _parentAddress.text = '${_s['parentAddress'] ?? ''}';
    _emergencyContact.text = '${_s['emergencyContact'] ?? ''}';
    _emergencyPhone.text = '${_s['emergencyPhone'] ?? ''}';
    _gender = '${_s['gender'] ?? 'MALE'}';
    _status = '${_s['status'] ?? 'ACTIVE'}';
    final bg = '${_s['bloodGroup'] ?? ''}';
    _bloodGroup = _bloodGroups.contains(bg) ? bg : null;
    _dob = _s['dateOfBirth'] != null
        ? DateTime.tryParse('${_s['dateOfBirth']}')
        : null;
    final av = _s['avatarUrl'] as String?;
    _avatarBase64 = (av != null && av.startsWith('data:image')) ? av : null;
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter a valid name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'fullName': _name.text.trim(),
      'gender': _gender,
      'status': _status,
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      if (_roll.text.trim().isNotEmpty)
        'rollNumber': int.tryParse(_roll.text.trim()),
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
    try {
      await ref
          .read(dioProvider)
          .patch('/teacher/students/${widget.studentId}', data: payload);
      if (!mounted) return;
      _changed = true;
      await _load();
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student details updated'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _purple,
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ?? 'Could not save';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not save';
        _saving = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text(_editing ? 'Edit Student' : 'Student Profile'),
          actions: [
            if (!_editing && !_loading)
              TextButton.icon(
                onPressed: _enterEdit,
                icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                label: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _editing
                ? _editView()
                : _readView(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // View
  // ---------------------------------------------------------------------
  Widget _readView() {
    final active = '${_s['status']}' == 'ACTIVE';
    final dob = _s['dateOfBirth'] != null
        ? DateTime.tryParse('${_s['dateOfBirth']}')
        : null;
    final avatar = _avatar(_s['avatarUrl'] as String?);
    final gender = '${_s['gender']}';
    final isFemale = gender == 'FEMALE';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        EntranceFade(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    image: avatar != null
                        ? DecorationImage(image: avatar, fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatar == null
                      ? Icon(
                          isFemale ? Icons.face_3_rounded : Icons.face_rounded,
                          color: Colors.white,
                          size: 42,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  '${_s['fullName'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _heroChip('${_s['class']?['name'] ?? ''}'),
                    _heroChip('Roll ${_s['rollNumber'] ?? '—'}'),
                    _heroChip(active ? 'Active' : 'Inactive'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        EntranceFade(
          delay: const Duration(milliseconds: 60),
          child: _section('Personal', Icons.person_rounded, [
            _row('Student Code', '${_s['studentCode'] ?? '—'}'),
            _row('Gender', gender == 'FEMALE' ? 'Female' : 'Male'),
            _row(
              'Date of Birth',
              dob == null ? '—' : DateFormat('d MMM yyyy').format(dob),
            ),
            _row('Blood Group', _val(_s['bloodGroup'])),
            _row('Email', _val(_s['email'])),
            _row('Phone', _val(_s['phone'])),
            _row('Address', _val(_s['address'])),
          ]),
        ),
        const SizedBox(height: 14),
        EntranceFade(
          delay: const Duration(milliseconds: 120),
          child: _section('Guardian', Icons.family_restroom_rounded, [
            _row('Father', _val(_s['fatherName'])),
            _row("Father's Phone", _val(_s['fatherPhone'])),
            _row("Father's Occupation", _val(_s['fatherOccupation'])),
            _row('Mother', _val(_s['motherName'])),
            _row("Mother's Phone", _val(_s['motherPhone'])),
            _row("Mother's Occupation", _val(_s['motherOccupation'])),
            _row('Parent Address', _val(_s['parentAddress'])),
          ]),
        ),
        const SizedBox(height: 14),
        EntranceFade(
          delay: const Duration(milliseconds: 180),
          child: _section('Emergency', Icons.emergency_rounded, [
            _row('Contact Name', _val(_s['emergencyContact'])),
            _row('Contact Phone', _val(_s['emergencyPhone'])),
          ]),
        ),
      ],
    );
  }

  String _val(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? '—' : s;
  }

  Widget _heroChip(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEEF5)),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(icon, size: 17, color: _purple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          ...rows,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: _ink.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------
  // Edit
  // ---------------------------------------------------------------------
  Widget _editView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Center(
          child: AdminAvatarPicker(
            imageBase64: _avatarBase64,
            onChanged: (v) => setState(() => _avatarBase64 = v),
          ),
        ),
        const SizedBox(height: 20),
        _editSection('Personal', [
          _field('Full name', _name),
          _field('Roll number', _roll, keyboard: TextInputType.number, digitsOnly: true),
          _dropdown('Gender', _gender, const ['MALE', 'FEMALE'],
              (v) => setState(() => _gender = v!), display: (v) => v == 'FEMALE' ? 'Female' : 'Male'),
          _dobField(),
          _dropdown<String?>('Blood group', _bloodGroup, [null, ..._bloodGroups],
              (v) => setState(() => _bloodGroup = v), display: (v) => v ?? 'Not set'),
          _dropdown('Status', _status, const ['ACTIVE', 'INACTIVE'],
              (v) => setState(() => _status = v!), display: (v) => v == 'ACTIVE' ? 'Active' : 'Inactive'),
          _field('Email', _email, keyboard: TextInputType.emailAddress),
          _field('Phone', _phone, keyboard: TextInputType.phone),
          _field('Address', _address, lines: 2),
        ]),
        const SizedBox(height: 14),
        _editSection('Guardian', [
          _field("Father's name", _fatherName),
          _field("Father's phone", _fatherPhone, keyboard: TextInputType.phone),
          _field("Father's occupation", _fatherOccupation),
          _field("Mother's name", _motherName),
          _field("Mother's phone", _motherPhone, keyboard: TextInputType.phone),
          _field("Mother's occupation", _motherOccupation),
          _field('Parent address', _parentAddress, lines: 2),
        ]),
        const SizedBox(height: 14),
        _editSection('Emergency', [
          _field('Contact name', _emergencyContact),
          _field('Contact phone', _emergencyPhone, keyboard: TextInputType.phone),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _editing = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink.withValues(alpha: 0.7),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _editSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    int lines = 1,
    bool digitsOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: lines,
        inputFormatters:
            digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(fontSize: 13.5, color: _ink),
        decoration: _decoration(label),
      ),
    );
  }

  Widget _dropdown<T>(
    String fieldLabel,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged, {
    required String Function(T) display,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: _decoration(fieldLabel),
        style: const TextStyle(fontSize: 13.5, color: _ink),
        items: items
            .map(
              (it) => DropdownMenuItem<T>(
                value: it,
                child: Text(display(it)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dob ?? DateTime(2014, 1, 1),
            firstDate: DateTime(1998),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _dob = picked);
        },
        child: InputDecorator(
          decoration: _decoration('Date of birth'),
          child: Text(
            _dob == null ? 'Select date' : DateFormat('d MMM yyyy').format(_dob!),
            style: TextStyle(
              fontSize: 13.5,
              color: _dob == null ? const Color(0xFF9CA3AF) : _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF6F6FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _purple, width: 1.4),
    ),
  );
}
