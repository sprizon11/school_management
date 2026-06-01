import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Login uses [assets/images/login_background.png] for branding/header/footer.
/// Only the form card, role shortcuts, and OR divider are drawn on top.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _bgAsset = 'assets/images/login_background.png';

  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('remember_identifier');
    if (id != null) _identifierCtrl.text = id;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).setLoading(true);
    ref.read(authProvider.notifier).setError(null);

    try {
      final dio = ref.read(dioProvider);
      final body = {
        'identifier': _identifierCtrl.text.trim(),
        'password': _passwordCtrl.text,
        if (_selectedRole != null) 'expectedRole': _selectedRole,
      };
      final res = await dio.post('/auth/login', data: body);
      final data = res.data as Map<String, dynamic>;
      await ref
          .read(authProvider.notifier)
          .saveSession(data['accessToken'] as String, data);

      if (_remember) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'remember_identifier',
          _identifierCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      final role = data['user']['role'] as String;
      if (role == 'ADMIN') context.go('/admin');
      if (role == 'TEACHER') context.go('/teacher');
      if (role == 'PARENT') context.go('/parent');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      ref.read(authProvider.notifier).setError(
            msg is List ? msg.join(', ') : msg?.toString() ?? 'Login failed',
          );
    } catch (_) {
      ref.read(authProvider.notifier).setError(
            'Cannot reach server. Start API & database.',
          );
    } finally {
      ref.read(authProvider.notifier).setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final keyboardH = media.viewInsets.bottom;
    final topSafe = media.padding.top;
    final bottomSafe = media.padding.bottom;

    return Scaffold(
      // Keep background fixed; only scroll the form when keyboard opens.
      resizeToAvoidBottomInset: false,
      body: SizedBox(
        height: screenH,
        width: media.size.width,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background never scrolls or resizes with keyboard.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenH,
              child: Image.asset(
                _bgAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.surface),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  topSafe + 8,
                  20,
                  keyboardH > 0 ? keyboardH + 20 : bottomSafe + 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clear logo + illustration in the background image.
                    SizedBox(height: screenH * 0.13),
                    const _BrandHeader(),
                    SizedBox(height: screenH * 0.018),
                    _LoginCard(
                      formKey: _formKey,
                      identifierCtrl: _identifierCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscure: _obscure,
                      remember: _remember,
                      loading: auth.loading,
                      error: auth.error,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onRememberChanged: (v) => setState(() => _remember = v ?? true),
                      onLogin: _login,
                    ),
                    const SizedBox(height: 14),
                    _OrDivider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            selected: _selectedRole == 'ADMIN',
                            title: 'Admin Login',
                            subtitle: 'Manage everything',
                            color: AppColors.primary,
                            icon: Icons.shield_outlined,
                            onTap: () => setState(() => _selectedRole = 'ADMIN'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RoleCard(
                            selected: _selectedRole == 'TEACHER',
                            title: 'Teacher Login',
                            subtitle: 'Manage your classes',
                            color: AppColors.success,
                            icon: Icons.menu_book_outlined,
                            onTap: () => setState(() => _selectedRole = 'TEACHER'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RoleCard(
                            selected: _selectedRole == 'PARENT',
                            title: 'Parent Login',
                            subtitle: 'Stay updated',
                            color: AppColors.parentPurple,
                            icon: Icons.family_restroom_outlined,
                            onTap: () => setState(() => _selectedRole = 'PARENT'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (keyboardH == 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomSafe + 12,
                child: const _SecurityFooterText(),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keep text on the left; illustration stays visible on the right.
      padding: const EdgeInsets.only(right: 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
              children: [
                TextSpan(text: 'Smart ', style: TextStyle(color: AppColors.primaryDark)),
                TextSpan(text: 'School', style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Management System',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: 'Connecting ', style: TextStyle(color: AppColors.primaryDark)),
                TextSpan(
                  text: 'Schools, Teachers,\nStudents & Parents',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain text only — sits on the blue strip in the background image.
class _SecurityFooterText extends StatelessWidget {
  const _SecurityFooterText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your data is safe and secure with us',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.95),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.identifierCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.remember,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onRememberChanged,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool remember;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 3),
            const Center(
              child: Text(
                'Login to continue to your account',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                height: 3,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: identifierCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                hintText: 'Mobile Number / Email',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                hintText: 'Password',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),
            Row(
              children: [
                SizedBox(
                  height: 32,
                  width: 32,
                  child: Checkbox(
                    value: remember,
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: onRememberChanged,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Remember Me', style: TextStyle(fontSize: 12.5)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Forgot Password?', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 2),
              Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: loading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textMuted,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: 28,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
