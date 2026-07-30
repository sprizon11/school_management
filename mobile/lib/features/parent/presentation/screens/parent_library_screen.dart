import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Books the child has borrowed from the school library (GET /parent/library):
/// currently borrowed (with overdue warnings) and past returns.
class ParentLibraryScreen extends ConsumerStatefulWidget {
  const ParentLibraryScreen({super.key});

  @override
  ConsumerState<ParentLibraryScreen> createState() =>
      _ParentLibraryScreenState();
}

class _ParentLibraryScreenState extends ConsumerState<ParentLibraryScreen> {
  static const _ink = Color(0xFF1A1533);
  static const _accent = AppColors.parentPrimary;
  static const _green = AppColors.statGreen;
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
      final res = await ref.read(dioProvider).get('/parent/library');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _borrowed => _items
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((b) => b['returnedAt'] == null)
      .toList();
  List<Map<String, dynamic>> get _history => _items
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((b) => b['returnedAt'] != null)
      .toList();

  @override
  Widget build(BuildContext context) {
    final borrowed = _borrowed;
    final history = _history;
    var index = 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Library'),
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
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      children: [
                        if (borrowed.isNotEmpty) ...[
                          _sectionHeader(
                            'Currently Borrowed',
                            borrowed.length,
                          ),
                          const SizedBox(height: 10),
                          for (final b in borrowed)
                            EntranceFadeItem(
                              index: index++,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _bookCard(b, current: true),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                        if (history.isNotEmpty) ...[
                          _sectionHeader('History', history.length),
                          const SizedBox(height: 10),
                          for (final b in history)
                            EntranceFadeItem(
                              index: index++,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _bookCard(b, current: false),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _sectionHeader(String text, int count) => Row(
    children: [
      Container(
        height: 17,
        width: 4,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B4BD6), Color(0xFF7C6BF0)],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink.withValues(alpha: 0.4),
        ),
      ),
    ],
  );

  Widget _bookCard(Map<String, dynamic> b, {required bool current}) {
    final overdue = b['overdue'] == true;
    final due = DateTime.tryParse('${b['dueDate'] ?? ''}');
    final returned = DateTime.tryParse('${b['returnedAt'] ?? ''}');
    final author = '${b['author'] ?? ''}';
    final category = '${b['category'] ?? ''}';

    final statusColor = !current ? _green : (overdue ? _red : _amber);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue ? _red.withValues(alpha: 0.35) : const Color(0xFFEFEFF6),
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book "spine".
          Container(
            height: 54,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withValues(alpha: 0.18),
                  statusColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: statusColor, width: 3),
              ),
            ),
            child: Icon(Icons.menu_book_rounded, size: 22, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${b['title'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        current
                            ? (due == null
                                ? ''
                                : overdue
                                    ? 'Overdue since ${DateFormat('d MMM').format(due.toLocal())}'
                                    : 'Due ${DateFormat('d MMM').format(due.toLocal())}')
                            : (returned == null
                                ? 'Returned'
                                : 'Returned ${DateFormat('d MMM').format(returned.toLocal())}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        Icons.local_library_rounded,
        size: 46,
        color: _accent.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No books borrowed',
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
