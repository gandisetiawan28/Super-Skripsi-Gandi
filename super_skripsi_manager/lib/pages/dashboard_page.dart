import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_indicator.dart';
import '../providers/documents_provider.dart';
import '../providers/server_provider.dart';
import '../providers/api_keys_provider.dart';
import '../providers/navigation_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final server = ref.watch(serverProvider);
    final apiKeys = ref.watch(apiKeysProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Dashboard',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selamat datang di Super Skripsi Gandi Manager',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: GlassmorphismTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.description_rounded,
                  label: 'Dokumen',
                  value: docs.whenOrNull(data: (d) => '${d.length}') ?? '...',
                  color: GlassmorphismTheme.primaryRed,
                  delay: const Duration(milliseconds: 100),
                ),
              ),
              Expanded(
                child: _StatCard(
                  icon: Icons.vpn_key_rounded,
                  label: 'API Keys',
                  value: '${apiKeys.length}',
                  color: GlassmorphismTheme.info,
                  delay: const Duration(milliseconds: 200),
                ),
              ),
              Expanded(
                child: _StatCard(
                  icon: Icons.dns_rounded,
                  label: 'Server',
                  value: server.isRunning ? 'Online' : 'Offline',
                  color: server.isRunning
                      ? GlassmorphismTheme.success
                      : GlassmorphismTheme.textSecondary,
                  delay: const Duration(milliseconds: 300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Server status card
          GlassCard(
            margin: EdgeInsets.zero,
            elevated: true,
            entranceDelay: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Local Server',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    StatusIndicator(
                      isActive: server.isRunning,
                      label: server.isRunning
                          ? 'Port ${server.port}'
                          : 'Stopped',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Server ini menghubungkan Manager dengan Word Add-in melalui HTTP API lokal.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: GlassmorphismTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: server.isRunning
                          ? () =>
                              ref.read(serverProvider.notifier).stopServer()
                          : () =>
                              ref.read(serverProvider.notifier).startServer(),
                      icon: Icon(
                        server.isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(server.isRunning ? 'Stop' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: server.isRunning
                            ? GlassmorphismTheme.textSecondary
                            : GlassmorphismTheme.primaryRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // System Hub Section
          Text(
            'System Management',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HubCard(
                icon: Icons.analytics_outlined,
                label: 'Usage',
                color: Colors.blue,
                onTap: () => ref.read(navigationProvider.notifier).state = 8,
              ),
              const SizedBox(width: 12),
              _HubCard(
                icon: Icons.key_outlined,
                label: 'API Keys',
                color: Colors.orange,
                onTap: () => ref.read(navigationProvider.notifier).state = 7,
              ),
              const SizedBox(width: 12),
              _HubCard(
                icon: Icons.terminal_outlined,
                label: 'Logs',
                color: Colors.purple,
                onTap: () => ref.read(navigationProvider.notifier).state = 10,
              ),
              const SizedBox(width: 12),
              _HubCard(
                icon: Icons.manage_search_rounded,
                label: 'RAG Explorer',
                color: Colors.indigo,
                onTap: () => ref.read(navigationProvider.notifier).state = 3,
              ),
              const SizedBox(width: 12),
              _HubCard(
                icon: Icons.install_desktop_outlined,
                label: 'Install',
                color: Colors.teal,
                onTap: () => ref.read(navigationProvider.notifier).state = 9,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent documents
          Text(
            'Dokumen Terbaru',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          docs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => GlassCard(
              margin: EdgeInsets.zero,
              child: Text('Error: $e', style: TextStyle(color: GlassmorphismTheme.error)),
            ),
            data: (documents) {
              if (documents.isEmpty) {
                return GlassCard(
                  margin: EdgeInsets.zero,
                  entranceDelay: const Duration(milliseconds: 500),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_open_rounded, size: 48,
                            color: GlassmorphismTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada dokumen. Upload PDF di tab Research.',
                          style: GoogleFonts.inter(
                            color: GlassmorphismTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final recentDocs = documents.take(5).toList();
              return Column(
                children: List.generate(recentDocs.length, (index) {
                  final doc = recentDocs[index];
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    entranceDelay: Duration(milliseconds: 500 + (index * 100)),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.picture_as_pdf_rounded,
                              color: GlassmorphismTheme.primaryRed, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${doc.authors.join(", ")} · ${doc.year ?? "n/a"}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: GlassmorphismTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: GlassmorphismTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${doc.chunkCount} chunks',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: GlassmorphismTheme.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Duration delay;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      elevated: true,
      entranceDelay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: GlassmorphismTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
