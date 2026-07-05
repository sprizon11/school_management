import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/teacher_ui.dart';

class TeacherClassesScreen extends ConsumerStatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  ConsumerState<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
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
            icon: Icons.school_rounded,
            title: 'My Classes',
            subtitle: '${_classes.length} assigned class${_classes.length == 1 ? '' : 'es'}',
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset.zero,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teacherPrimary))
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
                                      Icon(Icons.class_outlined, size: 48, color: AppColors.textMuted),
                                      SizedBox(height: 12),
                                      Text(
                                        'No classes assigned yet',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Ask your admin to assign you as class teacher.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                              itemBuilder: (_, i) => _classCard(_classes[i] as Map<String, dynamic>),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: teacherCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${c['grade']}${c['section']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['name'] ?? 'Class'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count students${c['room'] != null ? ' · Room ${c['room']}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${c['category'] ?? 'Class'}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teacherPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
