import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Leave applications for the child. Parents submit a request; the class
/// teacher approves or declines (GET/POST /parent/leave).
class ParentLeaveScreen extends ConsumerStatefulWidget {
  const ParentLeaveScreen({super.key});

  @override
  ConsumerState<ParentLeaveScreen> createState() => _ParentLeaveScreenState();
}

class _ParentLeaveScreenState extends ConsumerState<ParentLeaveScreen> {
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
      final res = await ref.read(dioProvider).get('/parent/leave');
      if (!mounted) return;
      setState(() {
        _items = res.data as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({Color color, Color ink, String label, IconData icon}) _statusStyle(
    String status,
  ) {
    switch (status) {
      case 'APPROVED':
        return (
          color: _green,
          ink: const Color(0xFF16A34A),
          label: 'Approved',
          icon: Icons.check_circle_rounded,
        );
      case 'REJECTED':
        return (
          color: _red,
          ink: const Color(0xFFB91C1C),
          label: 'Declined',
          icon: Icons.cancel_rounded,
        );
      default:
        return (
          color: _amber,
          ink: const Color(0xFFB45309),
          label: 'Pending',
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Leave Applications'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
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

  Widget _card(Map<String, dynamic> l) {
    final s = _statusStyle('${l['status']}');
    final from = DateTime.tryParse('${l['fromDate'] ?? ''}');
    final to = DateTime.tryParse('${l['toDate'] ?? ''}');
    final range = from == null
        ? ''
        : to == null || _sameDay(from, to)
            ? DateFormat('d MMM yyyy').format(from.toLocal())
            : '${DateFormat('d MMM').format(from.toLocal())} – ${DateFormat('d MMM yyyy').format(to.toLocal())}';
    final reason = '${l['reason'] ?? ''}';
    final note = '${l['reviewNote'] ?? ''}';
    final reviewer = '${l['reviewedBy'] ?? ''}';

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
            children: [
              Icon(Icons.date_range_rounded, size: 15, color: _accent),
              const SizedBox(width: 6),
              Text(
                range,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 12, color: s.ink),
                    const SizedBox(width: 4),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: s.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(
              fontSize: 12.5,
              color: _ink.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_rounded, size: 13, color: s.ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reviewer.isNotEmpty ? '$reviewer: $note' : note,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _ink.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------------------------------------------------------------------
  Future<void> _openForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LeaveForm(),
    );
    if (created == true) _load();
  }

  Widget _empty() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 90),
      Icon(
        Icons.event_note_rounded,
        size: 46,
        color: _accent.withValues(alpha: 0.5),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'No leave applications yet',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink.withValues(alpha: 0.6),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          'Tap Apply to request leave.',
          style: TextStyle(fontSize: 12, color: _ink.withValues(alpha: 0.45)),
        ),
      ),
    ],
  );
}

/// Bottom-sheet form to submit a leave request.
class _LeaveForm extends ConsumerStatefulWidget {
  const _LeaveForm();

  @override
  ConsumerState<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends ConsumerState<_LeaveForm> {
  static const _accent = AppColors.parentPrimary;
  static const _ink = Color(0xFF1A1533);

  DateTime? _from;
  DateTime? _to;
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Select' : DateFormat('d MMM yyyy').format(d);

  Future<void> _pick(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 120)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'Pick both dates');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a reason');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(dioProvider).post(
        '/parent/leave',
        data: {
          'fromDate': d(_from!),
          'toDate': d(_to!),
          'reason': _reason.text.trim(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ?? 'Could not submit';
        _saving = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not submit';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Apply for Leave',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('From', _from, () => _pick(true))),
                const SizedBox(width: 12),
                Expanded(child: _dateField('To', _to, () => _pick(false))),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Reason',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reason,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Family function, medical, travel…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF4F4FA),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: _accent,
                ),
                const SizedBox(width: 8),
                Text(
                  _fmt(value),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value == null ? const Color(0xFF9CA3AF) : _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
