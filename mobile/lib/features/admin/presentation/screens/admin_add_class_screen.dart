import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/admin_sub_page.dart';

class AdminAddClassScreen extends ConsumerStatefulWidget {
  const AdminAddClassScreen({
    super.key,
    this.onClassCreated,
    this.flowStep,
    this.flowTotal,
  });

  /// When set, called after class is saved instead of popping (add-student flow).
  final VoidCallback? onClassCreated;
  final int? flowStep;
  final int? flowTotal;

  @override
  ConsumerState<AdminAddClassScreen> createState() =>
      _AdminAddClassScreenState();
}

class _AdminAddClassScreenState extends ConsumerState<AdminAddClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _grade = TextEditingController(text: '10');
  final _section = TextEditingController(text: 'A');
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Secondary');
  final _room = TextEditingController();
  List<dynamic> _teachers = [];
  String? _teacherId;
  bool _loading = false;
  bool _loadingTeachers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _grade.dispose();
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
        _loadingTeachers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grade = int.parse(_grade.text.trim());
      final section = _section.text.trim().toUpperCase();
      await ref.read(dioProvider).post('/admin/classes', data: {
        'grade': grade,
        'section': section,
        'name': _name.text.trim().isEmpty ? 'Class $grade-$section' : _name.text.trim(),
        'category': _category.text.trim(),
        if (_room.text.trim().isNotEmpty) 'room': _room.text.trim(),
        if (_teacherId != null) 'classTeacherId': _teacherId,
      });
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
      final msg = e.response?.data?['message'];
      setState(() => _error = msg?.toString() ?? 'Failed to create class');
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
                          Row(
                            children: [
                              Expanded(
                                child: AdminFormField(
                                  label: 'Grade',
                                  controller: _grade,
                                  icon: Icons.looks_one_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      int.tryParse(v ?? '') == null ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AdminFormField(
                                  label: 'Section',
                                  controller: _section,
                                  icon: Icons.abc_rounded,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AdminFormField(
                            label: 'Class Name',
                            controller: _name,
                            hint: 'Class 10-A',
                            icon: Icons.class_rounded,
                          ),
                          const SizedBox(height: 16),
                          AdminFormField(
                            label: 'Category',
                            controller: _category,
                            hint: 'Secondary',
                            icon: Icons.category_rounded,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
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
                                value: _teacherId,
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
                                  const DropdownMenuItem(value: null, child: Text('None')),
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
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
}
