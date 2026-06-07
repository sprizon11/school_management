import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final statsFuture = dio.get('/admin/teachers/stats');
      final listFuture = dio.get(
        '/admin/teachers',
        queryParameters: {'limit': 50},
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
    } catch (e) {
      setState(() {
        _error = 'Could not load teachers';
        _loading = false;
      });
    }
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
                            SkeletonBox(height: 200, borderRadius: 16),
                          ],
                        ),
                      )
                    : _error != null
                    ? _errorState()
                    : Column(
                        children: [
                          const SizedBox(height: 14),
                          if (_stats != null) _statsRow(),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _items.isEmpty
                                ? _emptyState()
                                : RefreshIndicator(
                                    onRefresh: _load,
                                    child: ListView.separated(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      itemCount: _items.length,
                                      separatorBuilder: (_, __) => const Divider(
                                        height: 1,
                                        color: Color(0xFFF0F2F5),
                                      ),
                                      itemBuilder: (_, i) => _teacherRow(_items[i]),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teachers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Manage and view all teacher details',
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final total = _stats?['total'] as int? ?? 0;
    final newMonth = _stats?['newThisMonth'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              bg: const Color(0xFFEEF4FF),
              icon: Icons.school_rounded,
              iconColor: const Color(0xFF2D68FF),
              label: 'Total Teachers',
              value: '$total',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              bg: const Color(0xFFF3EEFF),
              icon: Icons.person_add_alt_1_rounded,
              iconColor: const Color(0xFF7C3AED),
              label: 'New This Month',
              value: '$newMonth',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFDBEAFE),
            backgroundImage: t['avatarUrl'] != null
                ? NetworkImage('${t['avatarUrl']}')
                : null,
            child: t['avatarUrl'] == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t['department'] ?? ''} · ${t['employeeCode'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if ('${t['classes'] ?? ''}'.isNotEmpty)
            Text(
              '${t['classes']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No teachers yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add teachers from Quick Access on the dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
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
