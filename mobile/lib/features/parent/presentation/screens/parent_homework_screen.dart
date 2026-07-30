import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Upcoming homework for the child's class (GET /parent/homework). Read-only.
class ParentHomeworkScreen extends ConsumerStatefulWidget {
  const ParentHomeworkScreen({super.key});

  @override
  ConsumerState<ParentHomeworkScreen> createState() =>
      _ParentHomeworkScreenState();
}

class _ParentHomeworkScreenState extends ConsumerState<ParentHomeworkScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _items.isEmpty);
    try {
      final res = await ref.read(dioProvider).get('/parent/homework');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Homework'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: _items.isEmpty
                  ? _empty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => EntranceFadeItem(
                        index: i,
                        child: _card(
                          Map<String, dynamic>.from(_items[i] as Map),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> h) {
    final due = DateTime.tryParse('${h['dueDate'] ?? ''}');
    final now = DateTime.now();
    final days = due == null
        ? null
        : DateTime(
            due.toLocal().year,
            due.toLocal().month,
            due.toLocal().day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final soon = days != null && days <= 1;
    final accent = soon ? _red : _amber;
    final accentInk = soon ? const Color(0xFFB91C1C) : const Color(0xFFB45309);
    final countdown = days == null
        ? ''
        : days <= 0
            ? 'Due today'
            : days == 1
                ? 'Due tomorrow'
                : 'In $days days';
    final dueLabel = due == null
        ? ''
        : DateFormat('EEE, d MMM').format(due.toLocal());
    final desc = '${h['description'] ?? ''}';
    final teacher = '${h['teacher'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEFF6)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 21,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${h['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (teacher.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        teacher,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _ink.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (countdown.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    countdown,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: accentInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12.5,
                color: _ink.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 13,
                color: _ink.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 5),
              Text(
                dueLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      Icon(
        Icons.check_circle_outline_rounded,
        size: 46,
        color: _accent.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No homework due',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink.withValues(alpha: 0.6),
          ),
        ),
      ),
    ],
  );
}
