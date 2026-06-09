import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import 'admin_add_class_screen.dart';
import 'admin_add_student_screen.dart';

/// Guides admin: create a class first (if none), then add student details.
class AdminAddStudentFlowScreen extends ConsumerStatefulWidget {
  const AdminAddStudentFlowScreen({super.key});

  @override
  ConsumerState<AdminAddStudentFlowScreen> createState() =>
      _AdminAddStudentFlowScreenState();
}

class _AdminAddStudentFlowScreenState
    extends ConsumerState<AdminAddStudentFlowScreen> {
  /// 1 = add class, 2 = add student
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _skipToStudentIfClassesExist();
  }

  Future<void> _skipToStudentIfClassesExist() async {
    try {
      final classes = await ref
          .read(adminClassesProvider.future)
          .timeout(const Duration(seconds: 12));
      if (classes.isNotEmpty && mounted) {
        setState(() => _step = 2);
      }
    } catch (_) {
      // Stay on add-class step — safe default when API is slow or empty.
    }
  }

  Future<void> _onClassCreated() async {
    ref.invalidate(adminClassesProvider);
    try {
      await ref
          .read(adminClassesProvider.future)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (mounted) setState(() => _step = 2);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 1) {
      return AdminAddClassScreen(
        onClassCreated: _onClassCreated,
        flowStep: 1,
        flowTotal: 2,
      );
    }

    return AdminAddStudentScreen(
      flowStep: 2,
      flowTotal: 2,
      onAddAnotherClass: () => setState(() => _step = 1),
    );
  }
}
