import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// Render free tier sleeps after ~15 min idle; first request can take 50–90s.
const cloudTimeout = Duration(seconds: 90);
const _cloudHosts = ['onrender.com', 'railway.app', 'fly.dev'];

bool get isCloudHosted {
  final url = ApiConfig.baseUrl.toLowerCase();
  return _cloudHosts.any(url.contains);
}

Dio _cloudDio() {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: cloudTimeout,
      receiveTimeout: cloudTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );
}

/// Ping API so Render wakes before the user taps Login.
Future<bool> wakeCloudServer() async {
  if (!isCloudHosted) return true;
  try {
    await _cloudDio().get('/health');
    return true;
  } catch (_) {
    return false;
  }
}

/// Retry GET while cloud host is cold-starting.
Future<Response<dynamic>> getWithCloudRetry(
  Dio dio,
  String path, {
  int maxAttempts = 3,
}) async {
  final opts = Options(
    sendTimeout: cloudTimeout,
    receiveTimeout: cloudTimeout,
  );

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await dio.get(path, options: opts);
    } on DioException catch (e) {
      final retriable = _isColdStartError(e);
      if (!retriable || attempt == maxAttempts) rethrow;
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }
  throw StateError('getWithCloudRetry exhausted');
}

/// Retry login while cloud host is cold-starting.
Future<Response<dynamic>> postWithCloudRetry(
  Dio dio,
  String path, {
  Object? data,
  int maxAttempts = 3,
  void Function(int attempt)? onRetry,
}) async {
  final opts = Options(
    sendTimeout: cloudTimeout,
    receiveTimeout: cloudTimeout,
  );

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await dio.post(path, data: data, options: opts);
    } on DioException catch (e) {
      final retriable = _isColdStartError(e);
      if (!retriable || attempt == maxAttempts) rethrow;
      onRetry?.call(attempt + 1);
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }
  throw StateError('postWithCloudRetry exhausted');
}

bool _isColdStartError(DioException e) {
  return e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.unknown;
}

String friendlyCloudError(DioException e) {
  if (_isColdStartError(e)) {
    return 'Server is still waking up. Wait 30s and tap Login again.';
  }
  final msg = e.response?.data?['message'];
  if (msg is List) {
    final text = msg.join(', ');
    if (text.contains('schoolId')) {
      return 'Please select your school first, then try logging in again.';
    }
    return text;
  }
  if (msg != null) {
    final text = msg.toString();
    if (text.contains('schoolId')) {
      return 'Please select your school first, then try logging in again.';
    }
    return text;
  }
  return 'Login failed. Check internet and try again.';
}
