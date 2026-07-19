import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'screens/parent_home_screen.dart';
import 'screens/parent_messages_screen.dart';

/// Parent shell. Home draws its own gradient header, so there is no AppBar —
/// the header runs to the top of the screen and the nav floats over the body.
class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ParentHomeScreen(onOpenMessages: () => setState(() => _index = 1)),
      const ParentMessagesScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6F6FB),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _ParentNavBar(
        index: _index,
        onTap: (i) async {
          if (i == 2) {
            await ref.read(authProvider.notifier).logout();
            return;
          }
          setState(() => _index = i);
        },
      ),
    );
  }
}

/// Frosted floating nav, matching the admin and teacher shells.
class _ParentNavBar extends StatelessWidget {
  const _ParentNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.chat_bubble_rounded, label: 'Messages'),
    (icon: Icons.logout_rounded, label: 'Log out'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe > 0 ? bottomSafe : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.parentPrimary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _items.length; i++) _item(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final selected = i == index;
    // Log out is an action, never a "current tab".
    final isAction = i == 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected && !isAction
              ? AppColors.parentPrimary.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _items[i].icon,
              size: 21,
              color: selected && !isAction
                  ? AppColors.parentPrimary
                  : const Color(0xFF8A8AA3),
            ),
            const SizedBox(height: 3),
            Text(
              _items[i].label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected && !isAction
                    ? AppColors.parentPrimary
                    : const Color(0xFF8A8AA3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
