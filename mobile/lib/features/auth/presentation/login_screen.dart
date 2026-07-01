import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/cloud_api.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Login uses [assets/images/login_background.png] for branding/header/footer.
/// User enters email + password; API role routes to admin or teacher home.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _bgAsset = 'assets/images/login_background.png';

  final _formKey = GlobalKey<FormState>();
  final _domainCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loggingIn = false;
  bool _wakingServer = false;
  bool _loadingSchools = true;
  String? _statusMessage;
  String? _schoolsError;
  String? _domainError;
  List<SelectedSchool> _schools = [];

  @override
  void initState() {
    super.initState();
    _loadRemembered();
    _prefetch();
    _loadSchools();
    if (isCloudHosted) _startServerWake();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loadingSchools = true;
      _schoolsError = null;
    });

    try {
      await ref.read(schoolReadyProvider.future);
      final dio = ref.read(dioProvider);
      final res = await getWithCloudRetry(dio, '/schools/public');
      final list = (res.data as List<dynamic>)
          .map((e) => SelectedSchool.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      // Keep a remembered school only if it still exists; otherwise clear it
      // so the user is returned to the domain step. We intentionally do NOT
      // auto-select single-school deployments — the domain step is the
      // consistent entry point for anyone who hasn't logged in before.
      final saved = ref.read(selectedSchoolProvider);
      if (saved != null && !list.any((s) => s.id == saved.id)) {
        await ref.read(selectedSchoolProvider.notifier).clear();
      }

      setState(() {
        _schools = list;
        _loadingSchools = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      setState(() {
        _loadingSchools = false;
        _schoolsError = status == 404
            ? 'School list not available yet. Deploy the latest backend, then retry.'
            : friendlyCloudError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSchools = false;
        _schoolsError = 'Could not load schools. Try again.';
      });
    }
  }

  void _prefetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage(_bgAsset), context);
    });
  }

  Future<void> _startServerWake() async {
    setState(() {
      _wakingServer = true;
      _statusMessage = 'Connecting to server (first time may take 60s)...';
    });
    final ok = await wakeCloudServer();
    if (!mounted) return;
    setState(() {
      _wakingServer = false;
      _statusMessage = ok ? 'Server ready. You can log in.' : null;
    });
    if (ok) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _statusMessage = null);
      });
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Step 1: resolve the typed school domain (its code) to a school and
  /// advance to the credentials step. Matches locally against the schools
  /// already loaded from /schools/public — no extra screen or API call.
  Future<void> _continueWithDomain() async {
    FocusScope.of(context).unfocus();
    final input = _domainCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _domainError = 'Please enter your school domain');
      return;
    }
    if (_loadingSchools) {
      setState(() => _domainError = 'Loading schools, please wait…');
      return;
    }
    if (_schoolsError != null) {
      await _loadSchools();
      return;
    }

    final lower = input.toLowerCase();
    SelectedSchool? match;
    for (final s in _schools) {
      if (s.code.toLowerCase() == lower) {
        match = s;
        break;
      }
    }
    match ??= () {
      for (final s in _schools) {
        if (s.code.toLowerCase().startsWith(lower) ||
            s.name.toLowerCase().contains(lower)) {
          return s;
        }
      }
      return null;
    }();

    if (match == null) {
      setState(() => _domainError = 'No school found for "$input"');
      return;
    }
    setState(() => _domainError = null);
    await ref.read(selectedSchoolProvider.notifier).select(match);
  }

  /// Go back to the domain step (from the credentials step). Prefills the
  /// domain field with the current school's code for quick editing.
  void _changeSchool() {
    final current = ref.read(selectedSchoolProvider);
    if (current != null) _domainCtrl.text = current.code;
    ref.read(authProvider.notifier).setError(null);
    ref.read(selectedSchoolProvider.notifier).clear();
    setState(() {
      _domainError = null;
      _statusMessage = null;
    });
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('remember_identifier');
    if (id != null) _identifierCtrl.text = id;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loggingIn = true);

    final authNotifier = ref.read(authProvider.notifier);
    authNotifier.setError(null);

    await ref.read(schoolReadyProvider.future);
    final school = ref.read(selectedSchoolProvider);
    if (school == null || school.id.trim().isEmpty) {
      authNotifier.setError('Please select your school.');
      setState(() => _loggingIn = false);
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final body = {
        'schoolId': school.id.trim(),
        'identifier': _identifierCtrl.text.trim(),
        'password': _passwordCtrl.text,
      };
      if (isCloudHosted) {
        setState(() {
          _statusMessage = 'Logging in — server may take up to 60s...';
        });
      }
      final res = await postWithCloudRetry(
        dio,
        '/auth/login',
        data: body,
        onRetry: (attempt) {
          if (!mounted) return;
          setState(() {
            _statusMessage = 'Server waking up... retry $attempt/3';
          });
        },
      );
      final data = res.data as Map<String, dynamic>;
      await authNotifier.saveSession(
        data['accessToken'] as String,
        data,
      );

      if (_remember) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'remember_identifier',
          _identifierCtrl.text.trim(),
        );
      }

      if (!mounted) return;

      final role = (data['user'] as Map<String, dynamic>)['role'] as String;
      final route = switch (role) {
        'ADMIN' => '/admin',
        'TEACHER' => '/teacher',
        'PARENT' => '/parent',
        _ => null,
      };
      setState(() => _statusMessage = null);
      if (route != null) context.go(route);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = null);
      authNotifier.setError(friendlyCloudError(e));
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');
      if (!mounted) return;
      authNotifier.setError(
        e is TypeError
            ? 'Unexpected server response. Try again.'
            : 'Login failed: $e',
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authError = ref.watch(authProvider.select((a) => a.error));
    final selectedSchool = ref.watch(selectedSchoolProvider);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final screenW = media.size.width;
    final keyboardH = media.viewInsets.bottom;
    final isWide = screenW > 600;
    final contentMaxWidth = isWide ? 460.0 : screenW;

    // Step is derived from whether a school is selected. A returning user
    // whose school was remembered skips straight to the credentials step;
    // "Change" clears the selection and returns to the domain step.
    final showCredentials = selectedSchool != null;

    final cardColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LoginCard(
          showCredentials: showCredentials,
          formKey: _formKey,
          domainCtrl: _domainCtrl,
          domainError: _domainError,
          identifierCtrl: _identifierCtrl,
          passwordCtrl: _passwordCtrl,
          obscure: _obscure,
          remember: _remember,
          loading: _loggingIn || _wakingServer,
          status: _statusMessage,
          error: authError,
          schoolsLoading: _loadingSchools,
          schoolsError: _schoolsError,
          selectedSchool: selectedSchool,
          onContinue: _continueWithDomain,
          onChangeSchool: _changeSchool,
          onRetrySchools: _loadSchools,
          onToggleObscure: () => setState(() => _obscure = !_obscure),
          onRememberChanged: (v) => setState(() => _remember = v ?? true),
          onLogin: _login,
        ),
        if (showCredentials) ...[
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 14),
          const _GoogleSignInButton(),
        ],
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              _bgAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: (screenW * media.devicePixelRatio).round(),
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.surface),
            ),
          ),

          // Header, card and footer laid out as siblings in a single flex
          // column (via SafeArea) so they can never overlap regardless of
          // per-device safe-area insets, text scale, or aspect ratio — the
          // previous approach positioned the header and card independently
          // by percentage, which drifted into overlap on some Android
          // devices. If content doesn't fit, it scrolls instead of
          // colliding.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableH = constraints.maxHeight - keyboardH;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: keyboardH),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableH > 0 ? availableH : 0,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: contentMaxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: screenH * 0.125),
                                // Constrain the brand block to the left ~60%
                                // so the text can never bleed into the
                                // illustration baked into the right side of
                                // the background image.
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: contentMaxWidth * 0.6,
                                    ),
                                    child: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: _BrandHeader(),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                cardColumn,
                                const SizedBox(height: 16),
                                if (keyboardH == 0) const _SecurityFooterText(),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1),
            children: [
              TextSpan(text: 'Smart ', style: TextStyle(color: AppColors.primaryDark)),
              TextSpan(text: 'School', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MANAGEMENT SYSTEM',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: 'Connecting ', style: TextStyle(color: AppColors.primaryDark)),
              TextSpan(
                text: 'Schools, Teachers\n& Students',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
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
    required this.showCredentials,
    required this.formKey,
    required this.domainCtrl,
    this.domainError,
    required this.identifierCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.remember,
    required this.loading,
    this.status,
    required this.error,
    required this.schoolsLoading,
    this.schoolsError,
    required this.selectedSchool,
    required this.onContinue,
    required this.onChangeSchool,
    required this.onRetrySchools,
    required this.onToggleObscure,
    required this.onRememberChanged,
    required this.onLogin,
  });

  final bool showCredentials;
  final GlobalKey<FormState> formKey;
  final TextEditingController domainCtrl;
  final String? domainError;
  final TextEditingController identifierCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool remember;
  final bool loading;
  final String? status;
  final String? error;
  final bool schoolsLoading;
  final String? schoolsError;
  final SelectedSchool? selectedSchool;
  final VoidCallback onContinue;
  final VoidCallback onChangeSchool;
  final VoidCallback onRetrySchools;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card top accent line
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              showCredentials ? 'Welcome Back!' : 'Get Started',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              showCredentials
                  ? 'Login to continue to your account'
                  : 'Enter your school domain to continue',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 13),
          if (showCredentials) _buildCredentialsStep() else _buildDomainStep(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — school domain
  // ---------------------------------------------------------------------------
  Widget _buildDomainStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: domainCtrl,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) {
            if (!schoolsLoading) onContinue();
          },
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.domain_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            hintText: 'School domain (e.g. greenfield)',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            errorText: domainError,
          ),
        ),
        if (schoolsError != null) ...[
          const SizedBox(height: 8),
          Text(
            schoolsError!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        _GradientButton(
          label: 'Continue',
          icon: Icons.arrow_forward_rounded,
          loading: schoolsLoading,
          onTap: schoolsLoading
              ? null
              : (schoolsError != null ? onRetrySchools : onContinue),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            "Ask your school admin if you don't know the domain",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — email + password
  // ---------------------------------------------------------------------------
  Widget _buildCredentialsStep() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected school chip with a "Change" affordance
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedSchool?.name ?? 'School',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if ((selectedSchool?.code ?? '').isNotEmpty)
                        Text(
                          selectedSchool!.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: loading ? null : onChangeSchool,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: identifierCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 20,
              ),
              hintText: 'Email',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!loading) onLogin();
            },
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.primary,
                size: 20,
              ),
              hintText: 'Password',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    status!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          _GradientButton(
            label: 'Sign In',
            icon: Icons.arrow_forward_rounded,
            loading: loading,
            onTap: loading ? null : onLogin,
          ),
        ],
      ),
    );
  }
}

/// Full-width gradient action button used for both "Continue" and "Sign In".
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.40),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.40),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.70),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleLogo(),
              const SizedBox(width: 10),
              const Text(
                'Sign in with Google',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3C4043),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.22;

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, h - stroke),
        start,
        sweep,
        false,
        paint,
      );
    }

    arc(const Color(0xFFEA4335), 3.65, 1.9);
    arc(const Color(0xFFFBBC05), 5.55, 1.45);
    arc(const Color(0xFF34A853), 0.95, 1.75);
    arc(const Color(0xFF4285F4), 2.7, 1.75);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(w * 0.52, h * 0.48),
      Offset(w * 0.88, h * 0.48),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

