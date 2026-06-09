import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

List<dynamic> parseClassesResponse(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['items'] is List) {
    return data['items'] as List<dynamic>;
  }
  return [];
}

/// Cached class list — shared across admin screens (no repeat fetches).
final adminClassesProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ref
      .read(dioProvider)
      .get('/admin/classes')
      .timeout(const Duration(seconds: 20));
  return parseClassesResponse(res.data);
});
