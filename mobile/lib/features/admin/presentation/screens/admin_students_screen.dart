import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/smooth_page_route.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/admin_cache_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';
import 'admin_add_student_flow_screen.dart';
import 'admin_student_detail_screen.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  List<dynamic> _items = [];
  List<dynamic> _classes = [];
  Map<String, dynamic>? _stats;
  static const _allStudentsLimit = 1000;
  bool _loading = true;
  String? _classFilter;
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
      setState(() => _loading = true);
    }
    try {
      final dio = ref.read(dioProvider);
      final statsFuture = dio.get('/admin/students/stats');
      final listFuture = dio.get(
        '/admin/students',
        queryParameters: {
          'page': 1,
          'limit': _allStudentsLimit,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          if (_classFilter != null) 'classId': _classFilter,
        },
      );
      final classesFuture =
          ref.read(adminClassesProvider.future).catchError((_) => <dynamic>[]);
      final statsRes = await statsFuture;
      final listRes = await listFuture;
      final classes = await classesFuture;
      final list = listRes.data as Map<String, dynamic>;
      var classFilter = _classFilter;
      if (classFilter != null &&
          !classes.any((c) => '${(c as Map)['id']}' == classFilter)) {
        classFilter = null;
      }
      setState(() {
        _stats = statsRes.data as Map<String, dynamic>;
        _items = list['items'] as List<dynamic>? ?? [];
        _classes = classes;
        _classFilter = classFilter;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  bool get _isFiltered =>
      _classFilter != null ||
      _search.text.trim().isNotEmpty ||
      _genderFilter != null;

  List<dynamic> get _visibleItems {
    if (_genderFilter == null) return _items;
    return _items
        .where((i) => '${(i as Map)['gender']}' == _genderFilter)
        .toList();
  }

  ImageProvider? _studentAvatar(String? url) {
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

  Map<String, dynamic> get _displayStats {
    if (!_isFiltered && _stats != null) return _stats!;
    final boys =
        _items.where((i) => '${(i as Map)['gender']}' == 'MALE').length;
    final girls =
        _items.where((i) => '${(i as Map)['gender']}' == 'FEMALE').length;
    final total = _items.length;
    return {
      'total': total,
      'boys': boys,
      'girls': girls,
      'boysPercent': total > 0 ? (boys / total * 1000).round() / 10 : 0,
      'girlsPercent': total > 0 ? (girls / total * 1000).round() / 10 : 0,
    };
  }

  void _openStudent(Map<String, dynamic> student) {
    final id = student['id'] as String?;
    if (id == null) return;
    openSmoothPage(context, AdminStudentDetailScreen(studentId: id));
  }

  Future<void> _openAddStudent() async {
    final added = await Navigator.of(context).push<bool>(
      SmoothPageRoute(page: const AdminAddStudentFlowScreen()),
    );
    if (added == true) _load();
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
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _visibleItems.isEmpty
                                ? _emptyState()
                                : ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 88),
                                    itemCount: _visibleItems.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: Color(0xFFF0F2F5),
                                    ),
                                    itemBuilder: (_, i) =>
                                        _studentRow(_visibleItems[i]),
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
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 28),
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
                  'Students',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage and view all student details',
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
    final boys = stats['boys'] as int? ?? 0;
    final girls = stats['girls'] as int? ?? 0;
    final boysPct = stats['boysPercent'] ?? 0;
    final girlsPct = stats['girlsPercent'] ?? 0;

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
              icon: Icons.boy_rounded,
              label: 'Boys',
              value: _formatNum(boys),
              badge: '$boysPct%',
              selected: _genderFilter == 'MALE',
              onTap: () => setState(() => _genderFilter = 'MALE'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              accent: const Color(0xFFDB2777),
              accentLight: const Color(0xFFFCE8F1),
              icon: Icons.girl_rounded,
              label: 'Girls',
              value: _formatNum(girls),
              badge: '$girlsPct%',
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _primaryAction(
              'Add Student',
              Icons.add_rounded,
              onTap: _openAddStudent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _outlineAction('Import', Icons.upload_rounded),
          ),
          const SizedBox(width: 6),
          Expanded(child: _outlineAction('Export', Icons.download_rounded)),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineAction(String label, IconData icon) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name, roll number, class...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF9CA3AF),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 110, maxWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _classFilter != null
                  ? const Color(0xFFEEF4FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _classFilter != null
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _classFilter,
                isDense: true,
                isExpanded: true,
                hint: const Text(
                  'All Classes',
                  style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                ),
                selectedItemBuilder: (_) => [
                  const Text(
                    'All Classes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  ..._classes.map((c) {
                    final m = c as Map<String, dynamic>;
                    return Text(
                      '${m['grade']}${m['section']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ],
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Classes', style: TextStyle(fontSize: 12)),
                  ),
                  ..._classes.map((c) {
                    final m = c as Map<String, dynamic>;
                    final id = '${m['id']}';
                    return DropdownMenuItem<String?>(
                      value: id,
                      child: Text(
                        'Class ${m['grade']}${m['section']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => _classFilter = v);
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4FA),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Student Name',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Roll No.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Class',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Section',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Status',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final filtered = _isFiltered;
    final title = _genderFilter == 'MALE'
        ? 'No boys found'
        : _genderFilter == 'FEMALE'
            ? 'No girls found'
            : filtered
                ? 'No matching students'
                : 'No students yet';
    final subtitle = filtered
        ? 'Try adjusting your search or filters.'
        : 'Add your first student to get started.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                filtered ? Icons.search_off_rounded : Icons.groups_rounded,
                size: 46,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            if (filtered)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _search.clear();
                    _classFilter = null;
                    _genderFilter = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _openAddStudent,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _studentRow(dynamic item) {
    final s = item as Map<String, dynamic>;
    final status = '${s['status']}';
    final isActive = status == 'ACTIVE';
    final gender = '${s['gender']}';
    final avatarColor = gender == 'FEMALE'
        ? const Color(0xFFFCE7F3)
        : const Color(0xFFDBEAFE);
    final avatarIconColor = gender == 'FEMALE'
        ? const Color(0xFFDB2777)
        : const Color(0xFF2563EB);
    final avatar = _studentAvatar(s['avatarUrl'] as String?);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openStudent(s),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: avatarColor,
                        backgroundImage: avatar,
                        child: avatar == null
                            ? Icon(Icons.person, size: 18, color: avatarIconColor)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['fullName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            Text(
                              '${s['studentCode']}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${s['rollNumber'] ?? '-'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: Text(
              '${s['grade']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: Text(
              '${s['section']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF166534)
                          : const Color(0xFF9A3412),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
