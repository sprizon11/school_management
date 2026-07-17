import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/motion.dart';

/// Floating "+" action for the admin tab screens.
///
/// The tab screens live inside [AdminShell]'s IndexedStack, not their own
/// Scaffold, so they can't use `Scaffold.floatingActionButton` — this is
/// positioned by hand instead.
///
/// Wrap a screen body with [AdminFabScaffold] rather than placing this
/// directly, so every screen sits it in the same spot.
class AdminFab extends StatelessWidget {
  const AdminFab({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// Gap between the FAB and the nav bar below it.
  ///
  /// The shell sets `extendBody: true`, so Scaffold already reports the nav
  /// bar's full height (plus any bottom safe-area) as the body's
  /// `padding.bottom`. Adding the nav height again on top of that pushed the
  /// button ~80px too high. Reading the inset also means this tracks the nav
  /// automatically if its height ever changes.
  static double bottomOffset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 16;

  @override
  Widget build(BuildContext context) {
    final button = PressableScale(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Places an [AdminFab] over a screen body, clear of the shell's nav bar.
class AdminFabScaffold extends StatelessWidget {
  const AdminFabScaffold({required this.child, required this.fab, super.key});

  final Widget child;
  final AdminFab fab;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: AdminFab.bottomOffset(context),
          child: fab,
        ),
      ],
    );
  }
}
