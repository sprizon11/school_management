import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/parent/presentation/parent_shell.dart';
import '../../features/teacher/presentation/teacher_shell.dart';
import '../providers/auth_provider.dart';

/// Notifies [GoRouter] when login/logout changes — without recreating the router.
final _authRefreshListenableProvider = Provider<ValueNotifier<int>>((ref) {
  final listenable = ValueNotifier(0);
  ref.listen(
    authProvider.select((a) => '${a.isLoggedIn}:${a.user?.role ?? ''}'),
    (_, __) => listenable.value++,
  );
  ref.onDispose(listenable.dispose);
  return listenable;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isPublic = loc == '/login';

      if (auth.isLoggedIn) {
        // An account still on a temporary password can't go anywhere until it
        // sets a real one.
        if (auth.user?.mustChangePassword == true) {
          return loc == '/change-password' ? null : '/change-password';
        }
        if (isPublic) {
          final role = auth.user?.role;
          if (role == 'ADMIN') return '/admin';
          if (role == 'TEACHER') return '/teacher';
          if (role == 'PARENT') return '/parent';
        }
        return null;
      }

      if (!isPublic) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
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
