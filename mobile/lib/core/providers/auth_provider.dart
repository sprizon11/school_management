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



  AuthUser({

    required this.id,

    this.schoolId = '',

    this.schoolName = '',

    required this.email,

    required this.fullName,

    required this.role,

    this.teacherId,

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

    );

  }

}



class AuthState {

  final String? token;

  final AuthUser? user;

  final bool loading;

  final String? error;



  const AuthState({

    this.token,

    this.user,

    this.loading = false,

    this.error,

  });



  bool get isLoggedIn => token != null && user != null;



  AuthState copyWith({

    String? token,

    AuthUser? user,

    bool? loading,

    String? error,

  }) {

    return AuthState(

      token: token ?? this.token,

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

  static const _userKey = 'auth_user';



  Future<void> _load() async {

    final token = await _storage.read(key: _tokenKey);

    final userJson = await _storage.read(key: _userKey);

    if (token != null && userJson != null) {

      state = AuthState(

        token: token,

        user: AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),

      );

    }

  }



  Future<void> saveSession(String token, Map<String, dynamic> response) async {

    final user = AuthUser.fromJson(response);

    await _storage.write(key: _tokenKey, value: token);

    await _storage.write(key: _userKey, value: jsonEncode(response['user']));

    state = AuthState(token: token, user: user);

  }



  Future<void> logout() async {

    await _storage.deleteAll();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('remember_identifier');

    state = const AuthState();

  }



  void setLoading(bool v) => state = state.copyWith(loading: v);

  void setError(String? e) => state = state.copyWith(error: e, loading: false);

}



final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(

  (ref) => AuthNotifier(),

);

