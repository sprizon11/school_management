import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../admin_shell.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get('/admin/teachers', queryParameters: {'limit': 20});
      setState(() {
        _items = (res.data as Map)['items'] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AdminHeader(title: 'Teachers', subtitle: 'Manage and view all teacher details'),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final t = _items[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(child: Text(t['fullName'][0])),
                      title: Text(t['fullName']),
                      subtitle: Text('${t['department']} · ${t['employeeCode']}'),
                      trailing: Text(t['classes']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
