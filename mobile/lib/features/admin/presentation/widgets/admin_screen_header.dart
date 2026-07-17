import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The admin screen header. Every admin screen uses this one, so the gradient,
/// spacing and action styling can't drift apart again.
///
/// Light treatment: controls sit on the page background as white circular
/// buttons, and the title block reads in ink below them. Content that follows
/// flows straight onto the page — there's no sheet to lap over.
class AdminScreenHeader extends StatelessWidget {
  const AdminScreenHeader({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.actions = const [],
    this.titleSize = 22,
    this.subtitleTrailing,
    this.icon,
    this.iconColor,
    super.key,
  });

  /// Main line — a screen name ("Students") or, on the dashboard, the person.
  final String title;

  /// Supporting line under [title].
  final String? subtitle;

  /// Small line above [title] (the dashboard's "Good Evening,").
  final String? eyebrow;

  /// Control at the far left of the top row — menu, or back on a sub-page.
  final Widget? leading;

  /// Trailing controls. Use [AdminHeaderIconButton] so they match.
  final List<Widget> actions;

  /// Screen names fit at the default; the dashboard turns it up for a name.
  final double titleSize;

  /// Small widget after [subtitle], e.g. the dashboard's verified tick.
  final Widget? subtitleTrailing;

  /// Screen glyph, shown in a tinted tile before the title. Gives the title
  /// something to sit against — naked text next to two floating buttons reads
  /// as unfinished. Ignored when [leading] is set (the dashboard's menu and a
  /// sub-page's back arrow own that slot).
  final IconData? icon;

  /// Tint for the [icon] tile. Defaults to the brand blue; list screens pass
  /// their own accent so the header ties to their stat cards.
  final Color? iconColor;

  static const ink = Color(0xFF1A1533);

  Widget _iconTile() {
    final tint = iconColor ?? AppColors.primary;
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.16), tint.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: tint, size: 21),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    // One row: control, title block, actions. Stacking them left a dead band
    // of empty space beside the buttons.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 10),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            _iconTile(),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                // scaleDown rather than ellipsis: a long name shrinks to fit
                // beside the buttons instead of becoming "Super Administr…".
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: ink,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (subtitleTrailing != null) ...[
                        const SizedBox(width: 4),
                        subtitleTrailing!,
                      ],
                    ],
                  ),
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

/// Content area beneath an [AdminScreenHeader].
///
/// Lays soft accent blooms over the page tint. They're what the glass surfaces
/// ([AdminGlassSurface]) actually blur — a BackdropFilter over a flat colour
/// blurs nothing and just looks like a tinted box, so without these the glass
/// treatment would be invisible.
class AdminScreenBody extends StatelessWidget {
  const AdminScreenBody({required this.child, this.color, super.key});

  final Widget child;
  final Color? color;

  /// Page tint behind the cards.
  static const pageBackground = Color(0xFFF7F7FC);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: color ?? pageBackground)),
          Positioned(
            left: -90,
            top: -60,
            child: _bloom(260, AppColors.primary, 0.16),
          ),
          Positioned(
            right: -80,
            top: 40,
            child: _bloom(220, const Color(0xFF7C3AED), 0.13),
          ),
          Positioned(
            left: 30,
            top: 260,
            child: _bloom(240, const Color(0xFF22C55E), 0.07),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _bloom(double size, Color tint, double alpha) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            tint.withValues(alpha: alpha),
            tint.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Frosted panel — the app's "liquid glass" surface.
///
/// Blurs whatever sits behind it, so it only reads against the blooms in
/// [AdminScreenBody]. Matches the login fields and the shell's nav bar.
class AdminGlassSurface extends StatelessWidget {
  const AdminGlassSurface({
    required this.child,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  /// Accent for the selected border and shadow. Defaults to the brand blue.
  final Color? tint;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? AppColors.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: selected ? 0.18 : 0.08),
            blurRadius: selected ? 18 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.08),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.58),
                      ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.75),
                width: selected ? 1.5 : 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// White circular control for [AdminScreenHeader].
class AdminHeaderIconButton extends StatelessWidget {
  const AdminHeaderIconButton({
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.showDot = false,
    this.plain = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Shows a count badge when > 0 (the dashboard's notification bell).
  final int badgeCount;

  /// Shows an unnumbered dot. Ignored when [badgeCount] > 0.
  final bool showDot;

  /// Drops the white pill and shadow — for the bare menu/back glyph.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      height: 44,
      width: 44,
      child: Icon(icon, color: AdminScreenHeader.ink, size: plain ? 24 : 21),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (plain)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: glyph,
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                child: glyph,
              ),
            ),
          ),
        if (badgeCount == 0 && showDot)
          Positioned(right: 4, top: 4, child: _dot(const Text(''))),
        if (badgeCount > 0)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(Widget _) => Container(
    height: 10,
    width: 10,
    decoration: BoxDecoration(
      color: const Color(0xFFF97316),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.6),
    ),
  );
}
