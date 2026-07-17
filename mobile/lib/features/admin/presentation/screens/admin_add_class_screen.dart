import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/senior_stream_groups.dart';
import '../widgets/admin_sub_page.dart';

class AdminAddClassScreen extends ConsumerStatefulWidget {
  const AdminAddClassScreen({
    super.key,
    this.onClassCreated,
    this.flowStep,
    this.flowTotal,
  });

  final VoidCallback? onClassCreated;
  final int? flowStep;
  final int? flowTotal;

  @override
  ConsumerState<AdminAddClassScreen> createState() =>
      _AdminAddClassScreenState();
}

class _AdminAddClassScreenState extends ConsumerState<AdminAddClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _section = TextEditingController(text: 'A');
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Secondary');
  final _room = TextEditingController();
  int _grade = 10;
  String? _streamGroup;
  List<dynamic> _teachers = [];
  String? _teacherId;
  bool _loading = false;
  bool _loadingTeachers = false;
  String? _error;

  bool get _isSenior => isSeniorGrade(_grade);

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _section.dispose();
    _name.dispose();
    _category.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loadingTeachers = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/admin/teachers', queryParameters: {'limit': 50})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _teachers = (res.data as Map)['items'] as List<dynamic>? ?? [];
        if (_teacherId != null &&
            !_teachers.any((t) => t['id'] == _teacherId)) {
          _teacherId = null;
        }
        _loadingTeachers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSenior && (_streamGroup == null || _streamGroup!.isEmpty)) {
      setState(() => _error = 'Please select a group for 11th or 12th class');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final section = _section.text.trim().toUpperCase();
      final teacherId =
          _teacherId != null && _teachers.any((t) => t['id'] == _teacherId)
          ? _teacherId
          : null;

      final payload = <String, dynamic>{
        'grade': _grade,
        'section': section,
        'name': _name.text.trim().isEmpty
            ? (_isSenior
                  ? 'Class $_grade-$section · $_streamGroup'
                  : 'Class $_grade-$section')
            : _name.text.trim(),
        if (!_isSenior) 'category': _category.text.trim(),
        if (_isSenior) ...{
          'category': _streamGroup,
          'streamGroup': _streamGroup,
        },
        if (_room.text.trim().isNotEmpty) 'room': _room.text.trim(),
        if (teacherId != null) 'classTeacherId': teacherId,
      };

      await ref.read(dioProvider).post('/admin/classes', data: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class created successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      if (widget.onClassCreated != null) {
        widget.onClassCreated!();
      } else {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data?['message'];
      final text = msg is List
          ? msg.map((m) => '$m').join('\n')
          : msg?.toString();
      setState(() {
        _error =
            text ??
            (e.response?.statusCode == 500
                ? 'Server error — check class teacher and try again'
                : 'Failed to create class');
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepLabel = widget.flowStep != null && widget.flowTotal != null
        ? 'Step ${widget.flowStep} of ${widget.flowTotal} · '
        : '';

    return AdminSubPageScaffold(
      title: 'Add Class',
      subtitle:
          '$stepLabel${widget.flowStep == 1 ? 'Create a class before adding students' : 'Create a new class and section'}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AdminPremiumCard(
                child: Column(
                  children: [
                    _dropdownField<int>(
                      label: 'Grade',
                      value: _grade,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('Grade ${i + 1}'),
                        ),
                      ),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _grade = v;
                          if (!isSeniorGrade(v)) _streamGroup = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    AdminFormField(
                      label: 'Section',
                      controller: _section,
                      icon: Icons.abc_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    if (_isSenior) ...[
                      const SizedBox(height: 16),
                      _dropdownField<String>(
                        label: 'Group name (required for 11th & 12th)',
                        value: _streamGroup,
                        hint: 'Select group — Accounts, Business Maths…',
                        items: seniorStreamGroups
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _streamGroup = v),
                        validator: (v) => _isSenior && (v == null || v.isEmpty)
                            ? 'Select a group'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AdminFormField(
                      label: 'Class Name',
                      controller: _name,
                      hint: _isSenior ? 'Class 11-A · Accounts' : 'Class 10-A',
                      icon: Icons.class_rounded,
                    ),
                    if (!_isSenior) ...[
                      const SizedBox(height: 16),
                      AdminFormField(
                        label: 'Category',
                        controller: _category,
                        hint: 'Secondary',
                        icon: Icons.category_rounded,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AdminFormField(
                      label: 'Room',
                      controller: _room,
                      hint: 'Room 201',
                      icon: Icons.meeting_room_outlined,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class Teacher (optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: _teacherId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          hint: Text(
                            _loadingTeachers
                                ? 'Loading teachers...'
                                : 'Select teacher',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None'),
                            ),
                            ..._teachers.map(
                              (t) => DropdownMenuItem(
                                value: t['id'] as String,
                                child: Text(t['fullName'] as String),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _teacherId = v),
                        ),
                      ],
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
                label: 'Create Class',
                icon: Icons.check_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? Function(T?)? validator,
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
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          hint: hint != null ? Text(hint) : null,
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
