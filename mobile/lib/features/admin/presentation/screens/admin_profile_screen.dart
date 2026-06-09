import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_sub_page.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _schoolName = TextEditingController();
  final _schoolPhone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _fullName = TextEditingController();
  final _adminPhone = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _schoolName.dispose();
    _schoolPhone.dispose();
    _address.dispose();
    _city.dispose();
    _fullName.dispose();
    _adminPhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/admin/profile');
      final data = res.data as Map<String, dynamic>;
      final school = data['school'] as Map<String, dynamic>? ?? {};
      final user = data['user'] as Map<String, dynamic>? ?? {};

      _schoolName.text = '${school['name'] ?? ''}';
      _schoolPhone.text = '${school['phone'] ?? ''}';
      _address.text = '${school['address'] ?? ''}';
      _city.text = '${school['city'] ?? ''}';
      _fullName.text = '${user['fullName'] ?? ''}';
      _adminPhone.text = '${user['phone'] ?? ''}';
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await ref.read(dioProvider).patch(
        '/admin/profile',
        data: {
          'name': _schoolName.text.trim(),
          'phone': _schoolPhone.text.trim(),
          'address': _address.text.trim(),
          'city': _city.text.trim(),
          'fullName': _fullName.text.trim(),
          'adminPhone': _adminPhone.text.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      final school = data['school'] as Map<String, dynamic>? ?? {};
      final user = data['user'] as Map<String, dynamic>? ?? {};

      await ref.read(authProvider.notifier).updateLocalProfile(
            schoolName: '${school['name'] ?? ''}',
            fullName: '${user['fullName'] ?? ''}',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated. School name syncs to developer portal.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubPageScaffold(
      title: 'Profile',
      subtitle: 'School & admin details',
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const AdminSectionTitle('School', icon: Icons.apartment_rounded),
                AdminPremiumCard(
                  child: Column(
                    children: [
                      AdminFormField(
                        label: 'School name',
                        controller: _schoolName,
                        icon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 14),
                      AdminFormField(
                        label: 'School phone',
                        controller: _schoolPhone,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      AdminFormField(
                        label: 'Address',
                        controller: _address,
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),
                      AdminFormField(
                        label: 'City',
                        controller: _city,
                        icon: Icons.location_city_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AdminSectionTitle('Administrator', icon: Icons.person_outline),
                AdminPremiumCard(
                  child: Column(
                    children: [
                      AdminFormField(
                        label: 'Your name',
                        controller: _fullName,
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 14),
                      AdminFormField(
                        label: 'Your phone',
                        controller: _adminPhone,
                        icon: Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AdminPrimaryButton(
                  label: 'Save profile',
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}
