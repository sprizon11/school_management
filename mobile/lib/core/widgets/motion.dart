import 'package:flutter/material.dart';

/// Shared entrance/press motion.
///
/// House motion spec: ~320ms, ease-out, short travel. Entering elements ease
/// out; presses squish. Stagger a few [EntranceFade]s ~60ms apart — enough to
/// read as sequenced, not enough to make someone wait for the UI.
///
/// Everything here collapses to a no-op when the platform asks for reduced
/// motion, so honouring that setting is never something a caller has to
/// remember.
const _entranceDuration = Duration(milliseconds: 320);

/// Fades and lifts its child into place on first build.
///
/// [delay] staggers siblings. Give one a [key] tied to the content when it
/// should replay on change; otherwise it plays once per mount.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _entranceDuration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Staggered [EntranceFade] for an item at [index] in a list.
///
/// Caps the delay so long lists don't leave later rows visibly trailing —
/// past the cap everything lands together.
class EntranceFadeItem extends StatelessWidget {
  const EntranceFadeItem({
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
    this.maxIndex = 8,
    super.key,
  });

  final int index;
  final Widget child;
  final Duration step;
  final int maxIndex;

  @override
  Widget build(BuildContext context) {
    final capped = index.clamp(0, maxIndex);
    return EntranceFade(delay: step * capped, child: child);
  }
}

/// Counts a number up from zero when it first appears.
///
/// Static figures land dead on a dashboard; a short roll-up reads as the data
/// arriving. Rounds to whole numbers, so it never shows a fractional count.
/// Shows the final value immediately under reduced motion.
class CountUpText extends StatelessWidget {
  const CountUpText({
    required this.value,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.format,
    super.key,
  });

  final num value;

  /// Trails the number, e.g. "%". Ignored when [format] is set.
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  /// Renders the in-flight value — e.g. currency grouping. Defaults to the
  /// rounded number plus [suffix].
  final String Function(int value)? format;

  String _render(double v) => format?.call(v.round()) ?? '${v.round()}$suffix';

  @override
  Widget build(BuildContext context) {
    final target = value.toDouble();

    if (MediaQuery.of(context).disableAnimations) {
      return Text(_render(target), style: style);
    }

    return TweenAnimationBuilder<double>(
      // Keyed by the target so a refresh re-runs the count rather than jumping.
      key: ValueKey(target),
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(_render(v), style: style),
    );
  }
}

/// Wraps a tappable in a press "squish".
///
/// An instant state change reads as unresponsive; this gives the touch
/// somewhere to land. Use around cards that already handle their own [onTap].
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
