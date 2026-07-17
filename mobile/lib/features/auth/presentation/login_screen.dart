import 'dart:math' as math;
import 'dart:ui';

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
import '../../../core/widgets/motion.dart';

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
      await authNotifier.saveSession(data['accessToken'] as String, data);

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

    // The full brand lockup (icon + "SmartUp" wordmark + tagline + school
    // illustration) is baked into the background image (853×1843, drawn
    // with BoxFit.cover + topCenter, so image top == screen top) — unlike
    // the old asset, there's no separate Flutter-rendered header text.
    // The illustration's curved bottom edge sits at y≈705px in image
    // coordinates; compute where that lands on this screen and start the
    // card right after it, with a safety-net minimum for unusual aspect
    // ratios (e.g. very short/wide screens).
    final bgScale = math.max(screenW / 853.0, screenH / 1843.0);
    final contentBottomOnScreen = 705.0 * bgScale;
    final cardTopGap = math.max(
      screenH * 0.34,
      contentBottomOnScreen - media.padding.top + 20,
    );

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
                          constraints: BoxConstraints(
                            maxWidth: contentMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Card sits right below the image's baked-in
                                // logo/illustration; this gap anchors the
                                // card's TOP edge at the same position on
                                // both steps — switching between the domain
                                // and credentials step only changes the
                                // card's content, not its placement.
                                SizedBox(height: cardTopGap),
                                cardColumn,
                                const SizedBox(height: 16),
                                const Spacer(),
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

/// Sits on the plain light-lavender lower section of the background image.
class _SecurityFooterText extends StatelessWidget {
  const _SecurityFooterText();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_rounded,
          size: 14,
          color: AppColors.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          'Your data is safe and secure with us',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryDark.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
        ),
      ],
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
    // No card: the fields sit straight on the background illustration as
    // frosted "liquid glass" panels (see [_GlassField]).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          // Steps slide in from the side they conceptually come from:
          // forward to credentials, back to the domain step.
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(showCredentials);
            final dx = (showCredentials ? 1.0 : -1.0) * (incoming ? 1 : -1);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.06 * dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(showCredentials),
            child: showCredentials
                ? _buildCredentialsStep()
                : _buildDomainStep(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — school domain
  // ---------------------------------------------------------------------------
  Widget _buildDomainStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EntranceFade(
          child: _StepGreeting(
            title: 'Get started',
            subtitle: 'Enter your school domain to continue',
          ),
        ),
        const SizedBox(height: 18),
        EntranceFade(
          delay: const Duration(milliseconds: 60),
          child: _GlassField(
            child: TextField(
              controller: domainCtrl,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              onSubmitted: (_) {
                if (!schoolsLoading) onContinue();
              },
              style: const TextStyle(fontSize: 14),
              decoration: _glassDecoration(
                icon: Icons.domain_rounded,
                hintText: 'School domain (e.g. greenfield)',
                errorText: domainError,
              ),
            ),
          ),
        ),
        if (schoolsError != null) ...[
          const SizedBox(height: 8),
          Text(
            schoolsError!,
            style: const TextStyle(color: Color(0xFFD92D20), fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        EntranceFade(
          delay: const Duration(milliseconds: 120),
          child: _GradientButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            loading: schoolsLoading,
            onTap: schoolsLoading
                ? null
                : (schoolsError != null ? onRetrySchools : onContinue),
          ),
        ),
        const SizedBox(height: 10),
        const EntranceFade(
          delay: Duration(milliseconds: 180),
          child: Center(
            child: Text(
              "Ask your school admin if you don't know the domain",
              textAlign: TextAlign.center,
              style: TextStyle(color: _onBackgroundMuted, fontSize: 11.5),
            ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          EntranceFade(
            child: _StepGreeting(
              title: 'Welcome back',
              subtitle: selectedSchool?.name == null
                  ? 'Sign in to continue'
                  : 'Sign in to ${selectedSchool!.name}',
            ),
          ),
          const SizedBox(height: 18),
          // Selected school chip with a "Change" affordance
          EntranceFade(
            delay: const Duration(milliseconds: 60),
            child: _GlassField(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          EntranceFade(
            delay: const Duration(milliseconds: 120),
            child: _GlassField(
              child: TextFormField(
                controller: identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14),
                decoration: _glassDecoration(
                  icon: Icons.person_outline,
                  hintText: 'Email',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          EntranceFade(
            delay: const Duration(milliseconds: 180),
            child: _GlassField(
              child: TextFormField(
                controller: passwordCtrl,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!loading) onLogin();
                },
                style: const TextStyle(fontSize: 14),
                decoration: _glassDecoration(
                  icon: Icons.lock_outline,
                  hintText: 'Password',
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
            ),
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

/// Secondary text colour for copy sitting directly on the login background.
///
/// [AppColors.textMuted] was picked for text on white cards; against the pale
/// lilac illustration it measures 4.18:1, under the 4.5:1 WCAG AA minimum.
/// This slate reads the same but measures 6.5:1.
const _onBackgroundMuted = Color(0xFF4B5563);

/// Step greeting. Sits directly on the background illustration, so it leans on
/// weight and a gradient wordmark for presence rather than a card behind it.
/// The background art already carries "SmartUp", so this greets rather than
/// re-brands.
class _StepGreeting extends StatelessWidget {
  const _StepGreeting({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
          ).createShader(bounds),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              height: 1.1,
              // Painted over by the shader; must be opaque white.
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: _onBackgroundMuted,
          ),
        ),
      ],
    );
  }
}

/// Frosted "liquid glass" shell for a login field.
///
/// The login fields sit directly on the background illustration rather than on
/// a card, so each one blurs what's behind it. Matches the liquid nav bars in
/// the admin/teacher shells. Pair with [_glassDecoration], which strips the
/// field's own fill and borders so only this shell is visible.
class _GlassField extends StatefulWidget {
  const _GlassField({required this.child});

  final Widget child;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Purely an observer: the TextField inside owns the real focus.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // The lift grows on focus, so the active field reads as raised.
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: _focused ? 0.22 : 0.10,
              ),
              blurRadius: _focused ? 28 : 16,
              offset: Offset(0, _focused ? 12 : 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                // Frosted, but opaque enough to keep hint/'text' legible
                // against the pale illustration behind it.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _focused ? 0.78 : 0.62),
                    Colors.white.withValues(alpha: _focused ? 0.62 : 0.44),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _focused
                      ? AppColors.primary.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.75),
                  width: _focused ? 1.6 : 1.2,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Input decoration for a field inside a [_GlassField]: the app-wide theme
/// fills inputs solid white, which would hide the blur behind them.
InputDecoration _glassDecoration({
  required IconData icon,
  required String hintText,
  Widget? suffixIcon,
  String? errorText,
}) {
  return InputDecoration(
    prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
    suffixIcon: suffixIcon,
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    errorText: errorText,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

/// Full-width gradient action button used for both "Continue" and "Sign In".
class _GradientButton extends StatefulWidget {
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
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    // Squish on press — an instant state change reads as unresponsive.
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      AppColors.primaryDark,
                      AppColors.primary,
                      AppColors.primaryLight,
                    ]
                  : [
                      AppColors.primary.withValues(alpha: 0.45),
                      AppColors.primaryLight.withValues(alpha: 0.45),
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: _pressed ? 0.22 : 0.40,
                ),
                blurRadius: _pressed ? 10 : 18,
                offset: Offset(0, _pressed ? 3 : 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              // 48px tall: comfortably clears the 44px minimum touch target.
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: widget.loading
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
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(widget.icon, color: Colors.white, size: 18),
                      ],
                    ),
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
