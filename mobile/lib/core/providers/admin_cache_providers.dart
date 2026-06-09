import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Cached class list — shared across admin screens (no repeat fetches).
final adminClassesProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final res = await ref
        .read(dioProvider)
        .get('/admin/classes')
        .timeout(const Duration(seconds: 20));
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    return [];
  } catch (_) {
    return [];
  }
});
