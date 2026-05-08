import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/glassmorphism_theme.dart';

class GlassDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double? maxWidth;

  const GlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 500),
        margin: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusLarge),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: GlassmorphismTheme.theme.dialogTheme.titleTextStyle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: GlassmorphismTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: content,
                      ),
                    ),
                    // Actions
                    if (actions != null && actions!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions!.map((a) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: a,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  double? maxWidth,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'GlassDialog',
    barrierColor: Colors.black.withOpacity(0.2),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return GlassDialog(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}
