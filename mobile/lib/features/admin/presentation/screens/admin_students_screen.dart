import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../admin_shell.dart';

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final stats = await dio.get('/admin/students/stats');
      final list = await dio.get('/admin/students', queryParameters: {
        'page': _page,
        'limit': 10,
        if (_search.text.isNotEmpty) 'search': _search.text,
      });
      setState(() {
        _stats = stats.data as Map<String, dynamic>;
        final data = list.data as Map<String, dynamic>;
        _items = data['items'] as List<dynamic>;
        _totalPages = data['totalPages'] as int? ?? 1;
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
        AdminHeader(title: 'Students', subtitle: 'Manage and view all student details'),
        if (_stats != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _miniStat('Total', '${_stats!['total']}', AppColors.primary)),
                Expanded(child: _miniStat('Boys', '${_stats!['boys']}', AppColors.statGreen)),
                Expanded(child: _miniStat('Girls', '${_stats!['girls']}', AppColors.statPink)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by name, roll number, class...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: () { _page = 1; _load(); }),
            ),
            onSubmitted: (_) { _page = 1; _load(); },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final s = _items[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(child: Text(s['fullName'][0])),
                      title: Text(s['fullName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s['studentCode']} · Class ${s['grade']}${s['section']}'),
                      trailing: Chip(
                        label: Text(s['status'], style: const TextStyle(fontSize: 10)),
                        backgroundColor: s['status'] == 'ACTIVE' ? Colors.green.shade50 : Colors.orange.shade50,
                      ),
                    );
                  },
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: _page > 1 ? () { _page--; _load(); } : null, icon: const Icon(Icons.chevron_left)),
            Text('Page $_page / $_totalPages'),
            IconButton(onPressed: _page < _totalPages ? () { _page++; _load(); } : null, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
