import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/motion.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _purple = Color(0xFF6D5DE8);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFEF4444);
  static const _blue = Color(0xFF3B82F6);
  static const _amber = Color(0xFFF59E0B);
  static const _grey = Color(0xFF9CA3AF);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _selectedClassId;
  List<dynamic> _roster = [];
  bool _rosterLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/attendance/overview');
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      final classes = data['classes'] as List<dynamic>? ?? [];
      setState(() {
        _data = data;
        _selectedClassId = classes.isNotEmpty
            ? '${(classes.first as Map)['id']}'
            : null;
        _loading = false;
      });
      if (_selectedClassId != null) _loadRoster(_selectedClassId!);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoster(String classId) async {
    setState(() => _rosterLoading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get(
            '/admin/students',
            queryParameters: {'classId': classId, 'limit': 200},
          );
      if (!mounted) return;
      setState(() {
        _roster = (res.data as Map)['items'] as List<dynamic>? ?? [];
        _rosterLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _rosterLoading = false);
    }
  }

  List<dynamic> get _classes => _data?['classes'] as List<dynamic>? ?? [];
  Map<String, dynamic> get _today =>
      _data?['today'] as Map<String, dynamic>? ?? {};
  List<dynamic> get _weekly => _data?['weekly'] as List<dynamic>? ?? [];

  Map<String, dynamic>? get _selectedClass {
    for (final c in _classes) {
      if ('${(c as Map)['id']}' == _selectedClassId) {
        return Map<String, dynamic>.from(c);
      }
    }
    return _classes.isNotEmpty
        ? Map<String, dynamic>.from(_classes.first as Map)
        : null;
  }

  int get _overallPercent {
    if (_weekly.isEmpty) return _toInt(_today['percent']);
    final sum = _weekly.fold<int>(
      0,
      (a, p) => a + _toInt((p as Map)['percent']),
    );
    return (sum / _weekly.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _purple),
                    )
                  : RefreshIndicator(
                      color: _purple,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                        children: [
                          EntranceFade(child: _statsRow()),
                          const SizedBox(height: 14),
                          EntranceFade(
                            delay: const Duration(milliseconds: 60),
                            child: _dateFilterRow(),
                          ),
                          const SizedBox(height: 14),
                          EntranceFade(
                            delay: const Duration(milliseconds: 110),
                            child: _classChips(),
                          ),
                          const SizedBox(height: 14),
                          EntranceFade(
                            delay: const Duration(milliseconds: 160),
                            child: _weekSelector(),
                          ),
                          const SizedBox(height: 16),
                          EntranceFade(
                            delay: const Duration(milliseconds: 210),
                            child: _classOverviewCard(),
                          ),
                          const SizedBox(height: 20),
                          _studentsHeader(),
                          const SizedBox(height: 10),
                          EntranceFade(
                            delay: const Duration(milliseconds: 260),
                            child: _studentsList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          _backButton(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track and manage student attendance',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _gradientButton(
            'Mark Attendance',
            Icons.event_available_rounded,
            () => _snack('Marking attendance — coming soon'),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _ink,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _gradientButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C6FF2), Color(0xFF6355E0)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _statsRow() {
    final total = _toInt(_today['totalStudents']);
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _statCard(
            Icons.groups_rounded,
            _green,
            '$_overallPercent%',
            'Overall Attendance',
            'This Month',
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.how_to_reg_rounded,
            _blue,
            '${_toInt(_today['present'])}',
            'Present Today',
            'of $total',
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.person_off_rounded,
            _red,
            '${_toInt(_today['absent'])}',
            'Absent Today',
            'of $total',
          ),
          const SizedBox(width: 12),
          _statCard(
            Icons.event_available_rounded,
            _amber,
            '${_classes.length}',
            'Classes Taken',
            'Today',
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    Color color,
    String value,
    String label,
    String sub,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              color: _ink.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _dateFilterRow() {
    return Row(
      children: [
        Expanded(
          child: _pill(
            Icons.calendar_today_rounded,
            'Date',
            '${DateFormat('d MMM yyyy').format(DateTime.now())} (Today)',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _pill(Icons.tune_rounded, 'Filter', 'All Classes')),
      ],
    );
  }

  Widget _pill(IconData icon, String label, String value) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _purple),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: _ink.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: _ink.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _classChips() {
    if (_classes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _classes.length,
        separatorBuilder: (_, i) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = _classes[i] as Map<String, dynamic>;
          final id = '${c['id']}';
          final selected = id == _selectedClassId;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedClassId = id);
              _loadRoster(id);
            },
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _purple.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected ? _purple : const Color(0xFFEDEFF4),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 20,
                    color: selected ? _purple : _ink.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${c['name'] ?? 'Class ${c['grade']}${c['section']}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? _purple : _ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${c['studentCount'] ?? 0} Students',
                    style: TextStyle(
                      fontSize: 10,
                      color: _ink.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _weekSelector() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.chevron_left_rounded, color: _ink.withValues(alpha: 0.35)),
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: _dayCell(
                labels[i],
                monday.add(Duration(days: i)),
                isToday:
                    monday.add(Duration(days: i)).day == now.day &&
                    monday.add(Duration(days: i)).month == now.month,
              ),
            ),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: _ink.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(String label, DateTime date, {required bool isToday}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: isToday ? _purple.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: isToday ? Border.all(color: _purple) : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isToday ? _purple : _ink.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isToday ? _purple : _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _classOverviewCard() {
    final c = _selectedClass;
    if (c == null) return const SizedBox.shrink();
    final total = _toInt(c['studentCount']);
    final marked = _toInt(c['marked']);
    final percent = _toInt(c['percent']);
    final present = (percent / 100 * total).round().clamp(0, total);
    final notMarked = (total - marked).clamp(0, total);
    final absent = (total - present - notMarked).clamp(0, total);
    const leave = 0;
    final name = '${c['name'] ?? 'Class ${c['grade']}${c['section']}'}';

    String pct(int v) => total > 0 ? (v / total * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name Attendance Overview',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$present / $total Present',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (present > 0)
                    Expanded(
                      flex: present,
                      child: Container(color: _green),
                    ),
                  if (absent > 0)
                    Expanded(
                      flex: absent,
                      child: Container(color: _red),
                    ),
                  if (notMarked > 0)
                    Expanded(
                      flex: notMarked,
                      child: Container(color: const Color(0xFFD1D5DB)),
                    ),
                  if (present + absent + notMarked == 0)
                    Expanded(child: Container(color: const Color(0xFFEDEFF4))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _legend(_green, 'Present', '$present (${pct(present)}%)'),
              _legend(_red, 'Absent', '$absent (${pct(absent)}%)'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legend(_blue, 'Leave', '$leave (${pct(leave)}%)'),
              _legend(_grey, 'Not Marked', '$notMarked (${pct(notMarked)}%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: _ink.withValues(alpha: 0.55),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  Widget _studentsHeader() {
    return Row(
      children: [
        Text(
          'Students (${_roster.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const Spacer(),
        Text(
          'Sort by: ',
          style: TextStyle(fontSize: 12.5, color: _ink.withValues(alpha: 0.5)),
        ),
        const Text(
          'Roll No.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _purple,
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _purple),
      ],
    );
  }

  Widget _studentsList() {
    if (_rosterLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }
    if (_roster.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: const Text(
          'No students in this class yet.',
          style: TextStyle(color: _grey),
        ),
      );
    }
    final sorted = [..._roster]
      ..sort(
        (a, b) => _toInt(
          (a as Map)['rollNumber'],
        ).compareTo(_toInt((b as Map)['rollNumber'])),
      );
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            _studentRow(sorted[i] as Map<String, dynamic>),
            if (i < sorted.length - 1)
              const Divider(
                height: 1,
                indent: 62,
                endIndent: 14,
                color: Color(0xFFF0F1F6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> s) {
    final name = '${s['fullName'] ?? '?'}';
    final roll = '${s['rollNumber'] ?? '—'}';
    final isFemale = '${s['gender']}' == 'FEMALE';
    final tint = isFemale ? const Color(0xFFEC4899) : _blue;
    final avatar = _avatar(s['avatarUrl'] as String?);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              image: avatar != null
                  ? DecorationImage(image: avatar, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatar == null
                ? Icon(
                    isFemale ? Icons.face_3_rounded : Icons.face_rounded,
                    color: tint,
                    size: 21,
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll No. ${roll.padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 13,
                  color: _grey,
                ),
                SizedBox(width: 4),
                Text(
                  'Not marked',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: _grey),
            onPressed: () => _snack('Marking attendance — coming soon'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: _purple.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _purple,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  ImageProvider? _avatar(String? url) {
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

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
