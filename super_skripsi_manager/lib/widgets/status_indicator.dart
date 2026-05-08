import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final String label;
  final double size;

  const StatusIndicator({
    super.key,
    required this.isActive,
    required this.label,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? GlassmorphismTheme.success
                : GlassmorphismTheme.textSecondary.withOpacity(0.4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: GlassmorphismTheme.success.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: GlassmorphismTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
