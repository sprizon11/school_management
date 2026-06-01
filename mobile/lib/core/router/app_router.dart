import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/teacher/presentation/teacher_shell.dart';
import '../../features/parent/presentation/parent_shell.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) {
        final role = auth.user!.role;
        if (role == 'ADMIN') return '/admin';
        if (role == 'TEACHER') return '/teacher';
        if (role == 'PARENT') return '/parent';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShell(),
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, __) => const TeacherShell(),
      ),
      GoRoute(
        path: '/parent',
        builder: (_, __) => const ParentShell(),
      ),
    ],
  );
});
