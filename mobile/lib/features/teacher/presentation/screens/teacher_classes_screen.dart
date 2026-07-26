import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';
import '../widgets/teacher_ui.dart';

class TeacherClassesScreen extends ConsumerStatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  ConsumerState<TeacherClassesScreen> createState() =>
      _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends ConsumerState<TeacherClassesScreen> {
  List<dynamic> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/teacher/classes');
      if (!mounted) return;
      setState(() {
        _classes = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _classes = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: teacherBg,
      child: Column(
        children: [
          TeacherPlainHeader(
            title: 'My Classes',
            subtitle:
                '${_classes.length} assigned class${_classes.length == 1 ? '' : 'es'}',
            showBack: true,
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset.zero,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.teacherPrimary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.teacherPrimary,
                      child: _classes.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: teacherCardDecoration(),
                                  child: const Column(
                                    children: [
                                      Icon(
                                        Icons.class_outlined,
                                        size: 48,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'No classes assigned yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Ask your admin to assign you as class teacher.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: _classes.length,
                              itemBuilder: (_, i) => EntranceFadeItem(
                                index: i,
                                child: _classCard(
                                  _classes[i] as Map<String, dynamic>,
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

  /// Rooms come through as either "001" or already-prefixed "Room 001"; avoid
  /// the "Room Room 001" double-label.
  String _roomLabel(dynamic room) {
    final r = '${room ?? ''}'.trim();
    if (r.isEmpty) return '';
    return r.toLowerCase().startsWith('room') ? r : 'Room $r';
  }

  Widget _classCard(Map<String, dynamic> c) {
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF16A34A),
      const Color(0xFFEA580C),
      const Color(0xFFDB2777),
    ];
    final color = colors[(c['grade'] as int? ?? 0) % colors.length];
    final count = c['_count']?['students'] ?? 0;
    final room = _roomLabel(c['room']);
    final category = '${c['category'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: teacherCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.72)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '${c['grade']}${c['section']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${c['name'] ?? 'Class'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (category.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: AppColors.teacherPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metaChip(
                  Icons.people_alt_rounded,
                  '$count student${count == 1 ? '' : 's'}',
                ),
                if (room.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _metaChip(Icons.meeting_room_rounded, room),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}
