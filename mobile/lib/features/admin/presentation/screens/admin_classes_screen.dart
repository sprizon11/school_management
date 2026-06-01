import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../admin_shell.dart';

class AdminClassesScreen extends ConsumerStatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  ConsumerState<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends ConsumerState<AdminClassesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get('/admin/classes');
      setState(() {
        _items = res.data as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.statPurple, AppColors.primary, AppColors.statGreen, AppColors.statOrange];
    return Column(
      children: [
        const AdminHeader(title: 'Classes', subtitle: 'Manage all classes and sections'),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final c = _items[i] as Map<String, dynamic>;
                    final color = colors[i % colors.length];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('${c['grade']}${c['section']}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                        ),
                        title: Text(c['name'] as String),
                        subtitle: Text('${c['category']} · ${c['studentCount']} students'),
                        trailing: Text(c['classTeacher']?['name'] ?? '', style: const TextStyle(fontSize: 11)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
