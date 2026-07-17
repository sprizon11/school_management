import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Search field shared by the admin list screens.
///
/// One implementation so Students, Teachers and Classes can't drift apart:
/// magnifier prefix, white fill on a hairline border, and the screen's accent
/// on focus. A clear "×" appears while there's text.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    required this.controller,
    required this.hint,
    this.accent,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    super.key,
  });

  final TextEditingController controller;
  final String hint;

  /// Focus border colour. Defaults to the brand blue.
  final Color? accent;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called when the clear "×" is tapped, after the field is emptied.
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () {
                      controller.clear();
                      onCleared?.call();
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: tint, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}
