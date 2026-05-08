import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';

class LogTerminal extends StatelessWidget {
  final List<String> logs;

  final VoidCallback? onClear;
  final VoidCallback? onStop;
  final bool isProcessing;

  const LogTerminal({
    super.key, 
    required this.logs, 
    this.onClear, 
    this.onStop,
    this.isProcessing = false,
  });

  void _copyToClipboard(BuildContext context) {
    if (logs.isEmpty) return;
    final fullLog = logs.join('\n');
    Clipboard.setData(ClipboardData(text: fullLog));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Log berhasil disalin ke clipboard!'),
        backgroundColor: GlassmorphismTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xF01A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5F57))),
              const SizedBox(width: 6),
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFBD2E))),
              const SizedBox(width: 6),
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF28C940))),
              const SizedBox(width: 12),
              Text('System Logs', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (isProcessing && onStop != null) ...[
                TextButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined, color: GlassmorphismTheme.error, size: 16),
                  label: const Text('STOP', style: TextStyle(color: GlassmorphismTheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(color: Colors.white10, width: 1, indent: 4, endIndent: 4),
                const SizedBox(width: 8),
              ],
              if (onClear != null && logs.isNotEmpty) ...[
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white30, size: 16),
                  tooltip: 'Bersihkan Log',
                ),
                const SizedBox(width: 12),
              ],
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy_rounded, color: Colors.white30, size: 16),
                tooltip: 'Salin Log',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet...',
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final log = logs[logs.length - 1 - index];
                      Color textColor = Colors.white70;
                      if (log.contains('[error]')) {
                        textColor = GlassmorphismTheme.error;
                      } else if (log.contains('[warn]')) {
                        textColor = GlassmorphismTheme.warning;
                      } else if (log.contains('✅') || log.contains('🎉')) {
                        textColor = GlassmorphismTheme.success;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            color: textColor,
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
