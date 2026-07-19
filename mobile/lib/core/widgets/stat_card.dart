import 'package:flutter/material.dart';
import 'motion.dart';
import '../../features/admin/presentation/widgets/admin_screen_header.dart';

/// Compact stat card used across the admin list screens.
///
/// Icon chip beside the figure, so three sit across a phone without
/// scrolling. Every list screen uses this one — Students, Teachers and Classes
/// each had their own near-identical version before.
///
/// Pass [onTap] to make it a filter: [selected] tints the surface, thickens
/// the border and deepens the shadow, animated so the state change doesn't
/// snap.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final IconData icon;

  /// Accent for the icon chip, the selected tint and the shadow.
  final Color color;

  final String value;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const _ink = Color(0xFF1A1533);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AdminGlassSurface(
        radius: 14,
        tint: color,
        selected: selected,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.05,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: _ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of [StatCard]s with the screens' shared spacing.
class StatRow extends StatelessWidget {
  const StatRow({required this.cards, super.key});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}
