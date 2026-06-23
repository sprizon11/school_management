import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedSchool {
  const SelectedSchool({
    required this.id,
    required this.name,
    required this.code,
    this.city,
    this.address,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String code;
  final String? city;
  final String? address;
  final String? logoUrl;

  factory SelectedSchool.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id == null || '$id'.trim().isEmpty) {
      throw FormatException('School id missing');
    }
    return SelectedSchool(
      id: '$id',
      name: '${json['name'] ?? 'School'}',
      code: '${json['code'] ?? ''}',
      city: json['city'] as String?,
      address: json['address'] as String?,
      logoUrl: json['logoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'city': city,
        'address': address,
        'logoUrl': logoUrl,
      };

  String get locationLabel {
    if (city != null && city!.isNotEmpty) return city!;
    if (address != null && address!.isNotEmpty) return address!;
    return code;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedSchool && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SelectedSchoolNotifier extends StateNotifier<SelectedSchool?> {
  SelectedSchoolNotifier() : super(null) {
    _ready = _loadFromPrefs();
  }

  static const _prefsKey = 'selected_school';
  late final Future<void> _ready;

  Future<void> ensureReady() => _ready;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      state = SelectedSchool.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      await prefs.remove(_prefsKey);
      state = null;
    }
  }

  Future<void> select(SelectedSchool school) async {
    if (school.id.trim().isEmpty) {
      throw ArgumentError('Invalid school id');
    }
    state = school;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(school.toJson()));
  }

  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

final selectedSchoolProvider =
    StateNotifierProvider<SelectedSchoolNotifier, SelectedSchool?>(
  (ref) => SelectedSchoolNotifier(),
);

/// Waits until saved school (if any) is loaded from device storage.
final schoolReadyProvider = FutureProvider<void>((ref) async {
  await ref.read(selectedSchoolProvider.notifier).ensureReady();
});
