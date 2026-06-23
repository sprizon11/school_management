import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared tab index for [TeacherShell] — lets dashboard deep-link to other tabs.
final teacherShellTabProvider = StateProvider<int>((ref) => 0);
