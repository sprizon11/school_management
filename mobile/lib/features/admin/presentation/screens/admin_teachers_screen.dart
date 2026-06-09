import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_add_teacher_screen.dart';
import 'admin_teacher_detail_screen.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  static const _allTeachersLimit = 1000;
  bool _loading = true;
  String? _error;
  String? _genderFilter;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showOverlay = false}) async {
    if (_stats == null || showOverlay) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dio = ref.read(dioProvider);
      final statsFuture = dio.get('/admin/teachers/stats');
      final listFuture = dio.get(
        '/admin/teachers',
        queryParameters: {
          'page': 1,
          'limit': _allTeachersLimit,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      final list = listRes.data as Map<String, dynamic>;
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = list['items'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      setState(() {
        _error = msg?.toString() ?? 'Could not load teachers';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load teachers';
        _loading = false;
      });
    }
  }

  bool get _isFiltered =>
      _search.text.trim().isNotEmpty || _genderFilter != null;

  List<dynamic> get _visibleItems {
    var items = _items;
    if (_genderFilter != null) {
      items = items
          .where((i) => '${(i as Map)['gender']}' == _genderFilter)
          .toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) {
      final t = i as Map;
      final name = '${t['fullName']}'.toLowerCase();
      final dept = '${t['department']}'.toLowerCase();
      final code = '${t['employeeCode']}'.toLowerCase();
      return name.contains(q) || dept.contains(q) || code.contains(q);
    }).toList();
  }

  Map<String, dynamic> get _displayStats {
    if (!_isFiltered && _stats != null) {
      return {
        'total': _stats!['total'] ?? 0,
        'male': _stats!['male'] ?? 0,
        'female': _stats!['female'] ?? 0,
        'malePercent': _stats!['malePercent'] ?? 0,
        'femalePercent': _stats!['femalePercent'] ?? 0,
      };
    }
    final gents =
        _items.where((i) => '${(i as Map)['gender']}' == 'MALE').length;
    final ladies =
        _items.where((i) => '${(i as Map)['gender']}' == 'FEMALE').length;
    final total = _items.length;
    return {
      'total': total,
      'male': gents,
      'female': ladies,
      'malePercent': total > 0 ? (gents / total * 1000).round() / 10 : 0,
      'femalePercent': total > 0 ? (ladies / total * 1000).round() / 10 : 0,
    };
  }

  Future<void> _openTeacher(Map<String, dynamic> teacher) async {
    final id = teacher['id'] as String?;
    if (id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: AdminTeacherDetailScreen(teacherId: id)),
    );
    if (changed == true) _load();
  }

  Future<void> _openAddTeacher() async {
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: const AdminAddTeacherScreen()),
    );
    if (added == true) _load();
  }

  ImageProvider? _teacherAvatar(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  String _formatNum(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final pos = s.length - i - 1;
      if (pos > 0 && pos % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: const Color(0xFFF4F6FA),
      child: Column(
        children: [
          _header(topPad),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: _loading && _stats == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SkeletonBox(height: 72, borderRadius: 16),
                            SizedBox(height: 12),
                            SkeletonBox(height: 48, borderRadius: 14),
                            SizedBox(height: 12),
                            SkeletonBox(height: 200, borderRadius: 16),
                          ],
                        ),
                      )
                    : _error != null && _stats == null
                    ? _errorState()
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          _statsRow(),
                          const SizedBox(height: 12),
                          _actionButtons(),
                          const SizedBox(height: 12),
                          _searchRow(),
                          const SizedBox(height: 8),
                          _tableHeader(),
                          Expanded(
                            child: _loading
                                ? const Center(child: CircularProgressIndicator())
                                : _visibleItems.isEmpty
                                ? _emptyState()
                                : RefreshIndicator(
                                    onRefresh: () => _load(showOverlay: true),
                                    child: ListView.separated(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(bottom: 88),
                                      itemCount: _visibleItems.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            color: Color(0xFFF0F2F5),
                                          ),
                                      itemBuilder: (_, i) =>
                                          _teacherRow(_visibleItems[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3FC9), Color(0xFF2368FF), Color(0xFF4388FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teachers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and view all teacher details',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _headerIconButton(Icons.refresh_rounded, onTap: () => _load(showOverlay: true)),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 36,
          width: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _statsRow() {
    final stats = _displayStats;
    final total = stats['total'] as int? ?? 0;
    final gents = stats['male'] as int? ?? 0;
    final ladies = stats['female'] as int? ?? 0;
    final gentsPct = stats['malePercent'] ?? 0;
    final ladiesPct = stats['femalePercent'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              accent: const Color(0xFF3B6FF5),
              accentLight: const Color(0xFFE8EFFF),
              icon: Icons.groups_rounded,
              label: 'Total',
              value: _formatNum(total),
              badge: 'All',
              selected: _genderFilter == null,
              onTap: () => setState(() => _genderFilter = null),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              accent: const Color(0xFF16A34A),
              accentLight: const Color(0xFFE8F8EE),
              icon: Icons.man_rounded,
              label: 'Gents',
              value: _formatNum(gents),
              badge: '$gentsPct%',
              selected: _genderFilter == 'MALE',
              onTap: () => setState(() => _genderFilter = 'MALE'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              accent: const Color(0xFFDB2777),
              accentLight: const Color(0xFFFCE8F1),
              icon: Icons.woman_rounded,
              label: 'Ladies',
              value: _formatNum(ladies),
              badge: '$ladiesPct%',
              selected: _genderFilter == 'FEMALE',
              onTap: () => setState(() => _genderFilter = 'FEMALE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Color accent,
    required Color accentLight,
    required IconData icon,
    required String label,
    required String value,
    required String badge,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? accentLight : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : accentLight,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.18 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _primaryAction('Add Teacher', Icons.add_rounded, onTap: _openAddTeacher),
    );
  }

  Widget _primaryAction(String label, IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by name, department or code...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B6FF5)),
          ),
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              'Name',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Department',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Text(
            'Status',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teacherRow(dynamic item) {
    final t = item as Map<String, dynamic>;
    final name = '${t['fullName'] ?? ''}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final gender = '${t['gender'] ?? 'MALE'}';
    final avatarColor = gender == 'FEMALE'
        ? const Color(0xFFFCE7F3)
        : const Color(0xFFDBEAFE);
    final initialColor = gender == 'FEMALE'
        ? const Color(0xFFDB2777)
        : const Color(0xFF2563EB);
    final avatar = _teacherAvatar(t['avatarUrl'] as String?);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor,
            backgroundImage: avatar,
            child: avatar == null
                ? Text(
                    initial,
                    style: TextStyle(
                      color: initialColor,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openTeacher(t),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t['employeeCode'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${t['department'] ?? ''}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final message = _genderFilter == 'MALE'
        ? 'No gents found'
        : _genderFilter == 'FEMALE'
        ? 'No ladies found'
        : _search.text.trim().isNotEmpty
        ? 'No teachers match your search'
        : 'No teachers yet';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            if (_genderFilter == null && _search.text.trim().isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Tap Add Teacher to create your first teacher profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openAddTeacher,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Teacher'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
