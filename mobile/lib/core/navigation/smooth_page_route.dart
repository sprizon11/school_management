import 'package:flutter/material.dart';

/// Route transition used for every pushed page in the app.
///
/// Incoming page slides in from the right with a fade while the outgoing page
/// parallaxes slightly left underneath — the stacked-cards feel, rather than
/// the old straight cross-fade. Reverse plays the same thing backwards, so
/// popping reads as returning, not as a new navigation.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({required Widget page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final incoming = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final outgoing = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return SlideTransition(
            // The page underneath drifts left as the new one covers it.
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.08, 0),
            ).animate(outgoing),
            child: FadeTransition(
              opacity: incoming,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.12, 0),
                  end: Offset.zero,
                ).animate(incoming),
                child: child,
              ),
            ),
          );
        },
      );
}

void openSmoothPage(BuildContext context, Widget page) {
  Navigator.of(context).push(SmoothPageRoute(page: page));
}
