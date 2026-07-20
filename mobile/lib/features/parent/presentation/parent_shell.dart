import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'screens/parent_home_screen.dart';
import 'screens/parent_marks_screen.dart';
import 'screens/parent_fees_screen.dart';
import 'screens/parent_messages_screen.dart';

/// Parent shell. Each tab draws its own header, so there is no AppBar — the
/// content runs to the top and the frosted nav floats over it.
class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  // 0 Home · 1 Marks · 2 Fees · 3 Messages. Log out (index 4) is an action.
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ParentHomeScreen(onOpenTab: (i) => setState(() => _index = i)),
      const ParentMarksScreen(),
      const ParentFeesScreen(),
      const ParentMessagesScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6F6FB),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _ParentNavBar(
        index: _index,
        onTap: (i) async {
          if (i == 4) {
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
    (icon: Icons.assignment_rounded, label: 'Marks'),
    (icon: Icons.receipt_long_rounded, label: 'Fees'),
    (icon: Icons.chat_bubble_rounded, label: 'Chat'),
    (icon: Icons.logout_rounded, label: 'Log out'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomSafe > 0 ? bottomSafe : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 66,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(child: _item(i)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final selected = i == index;
    // Log out is an action, never a "current tab".
    final isAction = i == 4;
    final active = selected && !isAction;
    final tint = active ? AppColors.parentPrimary : const Color(0xFF8A8AA3);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.parentPrimary.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_items[i].icon, size: 20, color: tint),
            const SizedBox(height: 3),
            Text(
              _items[i].label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
