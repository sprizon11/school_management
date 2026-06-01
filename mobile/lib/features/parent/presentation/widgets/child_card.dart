import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ChildCard extends StatelessWidget {
  const ChildCard({
    super.key,
    required this.name,
    required this.classLine,
    this.onSwitch,
  });

  final String name;
  final String classLine;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.parentPrimary.withValues(alpha: 0.15),
              child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.parentPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(classLine, style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            if (onSwitch != null)
              TextButton.icon(
                onPressed: onSwitch,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Switch Child'),
              ),
          ],
        ),
      ),
    );
  }
}
