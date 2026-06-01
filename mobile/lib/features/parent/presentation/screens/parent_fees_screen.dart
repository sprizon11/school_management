import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/child_card.dart';

class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _installments = [];
  List<dynamic> _breakdown = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sid = ref.read(selectedStudentIdProvider);
    if (sid == null) return;
    try {
      final dio = ref.read(dioProvider);
      final q = {'studentId': sid};
      final results = await Future.wait([
        dio.get('/parent/fees/summary', queryParameters: q),
        dio.get('/parent/fees/installments', queryParameters: q),
        dio.get('/parent/fees/breakdown', queryParameters: q),
      ]);
      setState(() {
        _summary = results[0].data as Map<String, dynamic>;
        _installments = results[1].data as List<dynamic>;
        _breakdown = results[2].data as List<dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Fees', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text("View your child's fee details and payment history", style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        const ChildCard(name: 'Aryan Kumar', classLine: 'Class 9A • Roll No. 15'),
        if (_summary != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _feeBox('Total', '₹${_summary!['total']}', AppColors.parentPrimary),
              _feeBox('Paid', '₹${_summary!['paid']}', AppColors.statGreen),
            ],
          ),
          Row(
            children: [
              _feeBox('Pending', '₹${_summary!['pending']}', AppColors.leaveOrange),
              _feeBox('Due', '${_summary!['daysLeft']} days', AppColors.primary),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Text('Installments', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._installments.map((i) {
          final m = i as Map<String, dynamic>;
          Color c = Colors.orange;
          if (m['status'] == 'PAID') c = Colors.green;
          if (m['status'] == 'UPCOMING') c = AppColors.parentPrimary;
          return ListTile(
            title: Text(m['label'] as String),
            subtitle: Text('₹${m['amount']} · Due ${m['dueDate'].toString().split('T').first}'),
            trailing: Chip(label: Text(m['status'] as String, style: const TextStyle(fontSize: 10)), backgroundColor: c.withValues(alpha: 0.15)),
          );
        }),
        const SizedBox(height: 16),
        const Text('Fee Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._breakdown.map((b) {
          final m = b as Map<String, dynamic>;
          return ListTile(
            title: Text(m['label'] as String),
            trailing: Text('₹${m['amount']}'),
          );
        }),
      ],
    );
  }

  Widget _feeBox(String label, String value, Color c) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
