import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Single-flight guard: many requests can 401 at once when the access token
  // expires; they all await the same refresh instead of stampeding it.
  Future<bool>? refreshing;

  Future<bool> refreshSession() async {
    final refreshToken = ref.read(authProvider).refreshToken;
    if (refreshToken == null) return false;
    try {
      // A bare Dio (no auth interceptor) so the refresh call itself can't loop.
      final res = await Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      ).post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = res.data as Map<String, dynamic>;
      await ref.read(authProvider.notifier).updateTokens(
            data['accessToken'] as String,
            data['refreshToken'] as String?,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authProvider).token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final status = e.response?.statusCode;
        final path = e.requestOptions.path;
        final isAuthCall = path.contains('/auth/');
        final alreadyRetried = e.requestOptions.extra['__retried'] == true;

        if (status == 401 &&
            !isAuthCall &&
            !alreadyRetried &&
            ref.read(authProvider).refreshToken != null) {
          refreshing ??= refreshSession().whenComplete(() => refreshing = null);
          final ok = await refreshing!;
          if (ok) {
            final req = e.requestOptions;
            req.extra['__retried'] = true;
            req.headers['Authorization'] =
                'Bearer ${ref.read(authProvider).token}';
            try {
              final clone = await dio.fetch(req);
              return handler.resolve(clone);
            } on DioException catch (err) {
              return handler.reject(err);
            }
          }
          // Refresh failed → the session is dead; sign out cleanly.
          await ref.read(authProvider.notifier).logout();
        }
        handler.next(e);
      },
    ),
  );

  return dio;
});
