import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String id;
  final String schoolId;
  final String schoolName;
  final String email;
  final String fullName;
  final String role;
  final String? teacherId;
  final bool mustChangePassword;

  AuthUser({
    required this.id,
    this.schoolId = '',
    this.schoolName = '',
    required this.email,
    required this.fullName,
    required this.role,
    this.teacherId,
    this.mustChangePassword = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    return AuthUser(
      id: user['id'] as String,
      schoolId: '${user['schoolId'] ?? ''}',
      schoolName: '${user['schoolName'] ?? ''}',
      email: user['email'] as String,
      fullName: user['fullName'] as String,
      role: user['role'] as String,
      teacherId: user['teacherId'] as String?,
      mustChangePassword: user['mustChangePassword'] == true,
    );
  }
}

class AuthState {
  final String? token;
  final String? refreshToken;
  final AuthUser? user;
  final bool loading;
  final String? error;

  const AuthState({
    this.token,
    this.refreshToken,
    this.user,
    this.loading = false,
    this.error,
  });

  bool get isLoggedIn => token != null && user != null;

  AuthState copyWith({
    String? token,
    String? refreshToken,
    AuthUser? user,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'auth_user';

  Future<void> _load() async {
    final token = await _storage.read(key: _tokenKey);
    final refresh = await _storage.read(key: _refreshKey);
    final userJson = await _storage.read(key: _userKey);
    if (token != null && userJson != null) {
      state = AuthState(
        token: token,
        refreshToken: refresh,
        user: AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
      );
    }
  }

  /// Persist a full login/refresh response ({ accessToken, refreshToken, user }).
  Future<void> saveSession(String token, Map<String, dynamic> response) async {
    final user = AuthUser.fromJson(response);
    final refresh = response['refreshToken'] as String?;
    await _storage.write(key: _tokenKey, value: token);
    if (refresh != null) {
      await _storage.write(key: _refreshKey, value: refresh);
    }
    await _storage.write(key: _userKey, value: jsonEncode(response['user']));
    state = AuthState(token: token, refreshToken: refresh, user: user);
  }

  /// Swap in rotated tokens after a silent /auth/refresh, keeping the user.
  Future<void> updateTokens(String token, String? refresh) async {
    await _storage.write(key: _tokenKey, value: token);
    if (refresh != null) {
      await _storage.write(key: _refreshKey, value: refresh);
    }
    state = state.copyWith(token: token, refreshToken: refresh);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_identifier');
    state = const AuthState();
  }

  void setLoading(bool v) => state = state.copyWith(loading: v);
  void setError(String? e) => state = state.copyWith(error: e, loading: false);

  Future<void> updateLocalProfile({
    String? schoolName,
    String? fullName,
  }) async {
    final user = state.user;
    if (user == null) return;

    final map = {
      'id': user.id,
      'schoolId': user.schoolId,
      'schoolName': schoolName ?? user.schoolName,
      'email': user.email,
      'fullName': fullName ?? user.fullName,
      'role': user.role,
      if (user.teacherId != null) 'teacherId': user.teacherId,
      'mustChangePassword': user.mustChangePassword,
    };

    await _storage.write(key: _userKey, value: jsonEncode(map));
    state = state.copyWith(user: AuthUser.fromJson(map));
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
