import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// School calendar for parents — an agenda of upcoming events grouped by month.
/// Read-only; events are created by the school (GET /parent/events).
class ParentCalendarScreen extends ConsumerStatefulWidget {
  const ParentCalendarScreen({super.key});

  @override
  ConsumerState<ParentCalendarScreen> createState() =>
      _ParentCalendarScreenState();
}

class _ParentCalendarScreenState extends ConsumerState<ParentCalendarScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;

  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _events.isEmpty);
    try {
      final res = await ref.read(dioProvider).get('/parent/events');
      if (!mounted) return;
      setState(() {
        _events = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _categoryColor(Map<String, dynamic> e) {
    final raw = '${e['color'] ?? ''}';
    if (raw.startsWith('#') && raw.length == 7) {
      return Color(int.parse('FF${raw.substring(1)}', radix: 16));
    }
    return _accent;
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'holiday':
        return Icons.beach_access_rounded;
      case 'exam':
        return Icons.edit_note_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      case 'activity':
        return Icons.celebration_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  /// Events grouped under a "July 2026" style month header.
  Map<String, List<Map<String, dynamic>>> get _byMonth {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final raw in _events) {
      final e = Map<String, dynamic>.from(raw as Map);
      final d = DateTime.tryParse('${e['startAt'] ?? ''}');
      final key = d == null ? 'Upcoming' : DateFormat('MMMM yyyy').format(d);
      out.putIfAbsent(key, () => []).add(e);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('School Calendar'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: _events.isEmpty ? _empty() : _agenda(),
            ),
    );
  }

  Widget _agenda() {
    final groups = _byMonth;
    final months = groups.keys.toList();
    var index = 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (final month in months) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
            child: Text(
              month,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          for (final e in groups[month]!)
            EntranceFadeItem(
              index: index++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _eventCard(e),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final color = _categoryColor(e);
    final start = DateTime.tryParse('${e['startAt'] ?? ''}');
    final category = '${e['category'] ?? 'Event'}';
    final location = '${e['location'] ?? ''}';
    final desc = '${e['description'] ?? ''}';
    final timeLabel = start == null
        ? ''
        : DateFormat('h:mm a').format(start.toLocal());

    return Container(
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured date rail.
            Container(
              width: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    start == null ? '' : DateFormat('EEE').format(start),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    start == null ? '—' : '${start.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    start == null ? '' : DateFormat('MMM').format(start),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categoryIcon(category),
                                size: 12,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _ink.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${e['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 12,
                            color: _ink.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _ink.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _ink.withValues(alpha: 0.55),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      Icon(
        Icons.event_available_rounded,
        size: 46,
        color: _accent.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No upcoming events',
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
