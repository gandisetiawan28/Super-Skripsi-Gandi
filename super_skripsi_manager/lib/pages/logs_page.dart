import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/log_terminal.dart';
import '../widgets/glass_card.dart';
import '../theme/glassmorphism_theme.dart';
import '../providers/server_provider.dart';
import '../providers/api_bridge_provider.dart';
import '../providers/rag_service_provider.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Logs',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: GlassmorphismTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Real-time monitoring server dan proses dokumen',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: GlassmorphismTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () =>
                    ref.read(serverProvider.notifier).clearLogs(),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear Logs'),
                style: TextButton.styleFrom(
                  foregroundColor: GlassmorphismTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── Word Bridge Status Card ───
          GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: server.isRunning
                      ? GlassmorphismTheme.success
                      : const Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📝 Word Bridge (MS Word Add-in)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GlassmorphismTheme.textPrimary,
                        ),
                      ),
                      Text(
                        server.isRunning
                            ? 'Aktif di http://127.0.0.1:${server.port}'
                            : 'Tidak aktif — Word Add-in tidak dapat terhubung.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: server.isRunning
                              ? GlassmorphismTheme.success
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Toggle button
                _ServerToggleButton(
                  isRunning: server.isRunning,
                  onStart: () => ref.read(serverProvider.notifier).startServer(),
                  onStop: () => ref.read(serverProvider.notifier).stopServer(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ─── Extension Bridge Status Card ───
          Builder(
            builder: (context) {
              final apiService = ref.watch(apiBridgeProvider);
              return GlassCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.extension_outlined,
                      color: apiService.isRunning
                          ? GlassmorphismTheme.success
                          : const Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🧩 Extension Bridge (Browser)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GlassmorphismTheme.textPrimary,
                            ),
                          ),
                          Text(
                            apiService.isRunning
                                ? 'Aktif di http://127.0.0.1:3000'
                                : 'Tidak aktif — Browser Extension tidak dapat terhubung.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: apiService.isRunning
                                  ? GlassmorphismTheme.success
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Toggle button
                    _ServerToggleButton(
                      isRunning: apiService.isRunning,
                      onStart: () => apiService.startServer(),
                      onStop: () {
                        // Bersihkan AI di browser dulu sebelum server dimatikan
                        ref.read(ragStateProvider.notifier).abortIndexing();
                        apiService.stopServer();
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ─── Terminal Log ───
          Expanded(
            child: LogTerminal(logs: server.logs),
          ),
        ],
      ),
    );
  }
}

/// Tombol toggle Start/Stop yang reusable
class _ServerToggleButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _ServerToggleButton({
    required this.isRunning,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: isRunning
          ? OutlinedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Stop'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_circle_outlined, size: 16),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                backgroundColor: GlassmorphismTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

