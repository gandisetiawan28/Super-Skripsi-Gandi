import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pk_provider;
import 'package:intl/intl.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/sparkline_chart.dart';
import '../providers/stats_provider.dart';

class ExtensionPage extends StatelessWidget {
  const ExtensionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: pk_provider.Consumer<StatsProvider>(
        builder: (context, stats, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(stats.isOnline),
                const SizedBox(height: 24),
                _buildStatsRow(stats),
                const SizedBox(height: 32),
                _buildSectionHeader('Providers Status'),
                const SizedBox(height: 16),
                _buildProvidersGrid(stats),
                const SizedBox(height: 32),
                _buildSectionHeader('Recent Activity'),
                const SizedBox(height: 16),
                _buildActivityLog(stats),
                const SizedBox(height: 120), // Space for dock
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GlassmorphismTheme.textPrimary,
      ),
    );
  }

  Widget _buildHeader(bool isOnline) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Extension Console',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: GlassmorphismTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Monitoring endpoint dan status koneksi real-time.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: GlassmorphismTheme.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        _LiveStatus(isOnline: isOnline),
      ],
    );
  }

  Widget _buildStatsRow(StatsProvider stats) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'UPTIME',
            value: _formatUptime(stats.uptime),
            icon: Icons.timer_outlined,
            color: const Color(0xFF60A5FA),
            delay: const Duration(milliseconds: 100),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'TOTAL HITS',
            value: stats.totalRequests.toString(),
            icon: Icons.bolt_rounded,
            color: const Color(0xFFF472B6),
            delay: const Duration(milliseconds: 200),
            history: stats.requestHistory,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'SUCCESS RATE',
            value: '${stats.successRate}%',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF34D399),
            delay: const Duration(milliseconds: 300),
          ),
        ),
      ],
    );
  }

  Widget _buildProvidersGrid(StatsProvider stats) {
    final providerList = [
      {'id': 'gemini', 'name': 'Google Gemini', 'color': Colors.blue},
      {'id': 'chatgpt', 'name': 'ChatGPT', 'color': Colors.teal},
      {'id': 'claude', 'name': 'Claude.ai', 'color': Colors.orange},
      {'id': 'deepseek', 'name': 'DeepSeek', 'color': Colors.deepPurple},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemCount: providerList.length,
      itemBuilder: (context, index) {
        final pInfo = providerList[index];
        final pStatus = stats.providers.firstWhere(
          (p) => p['provider'] == pInfo['id'],
          orElse: () => {'online': false, 'lastSeen': null},
        );

        final bool isOnline = pStatus['online'] ?? false;
        final String lastSeenStr = pStatus['lastSeen'] != null 
            ? DateFormat('HH:mm:ss').format(DateTime.parse(pStatus['lastSeen']))
            : 'Never';
        final int latency = pStatus['latency'] ?? 0;

        return _ProviderStatusCard(
          name: pInfo['name'] as String,
          isOnline: isOnline,
          lastSeen: lastSeenStr,
          latency: latency,
          color: pInfo['color'] as Color,
          delay: Duration(milliseconds: 400 + (index * 100)),
        );
      },
    );
  }

  Widget _buildActivityLog(StatsProvider stats) {
    if (stats.activityLog.isEmpty) {
      return GlassCard(
        height: 100,
        child: Center(
          child: Text(
            'No recent activity recorded.',
            style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary),
          ),
        ),
      );
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.activityLog.length.clamp(0, 8),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: GlassmorphismTheme.textSecondary.withOpacity(0.05),
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final log = stats.activityLog[index];
          final time = DateFormat('HH:mm:ss').format(DateTime.parse(log['time']));
          final bool isError = log['type'] == 'error';

          return ListTile(
            dense: true,
            leading: Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 18,
              color: isError ? Colors.red : GlassmorphismTheme.primaryRed.withOpacity(0.5),
            ),
            title: Text(
              log['message'],
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: GlassmorphismTheme.textPrimary,
              ),
            ),
            trailing: Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: GlassmorphismTheme.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m';
    return '${(seconds / 3600).floor()}h ${((seconds % 3600) / 60).floor()}m';
  }
}

class _ProviderStatusCard extends StatelessWidget {
  final String name;
  final bool isOnline;
  final String lastSeen;
  final int latency;
  final Color color;
  final Duration delay;

  const _ProviderStatusCard({
    required this.name,
    required this.isOnline,
    required this.lastSeen,
    required this.latency,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      elevated: true,
      entranceDelay: delay,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOnline ? Icons.hub_rounded : Icons.hub_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GlassmorphismTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.green : Colors.red,
                        boxShadow: [
                          if (isOnline)
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                    if (isOnline && latency > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•  ${latency}ms',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: GlassmorphismTheme.textSecondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      lastSeen,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Duration delay;
  final List<double>? history;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.delay,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      elevated: true,
      entranceDelay: delay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: color.withOpacity(0.8),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
              if (history != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: SparklineChart(
                      data: history!,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  final bool isOnline;

  const _LiveStatus({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isOnline ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOnline ? Colors.green : Colors.red).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? Colors.green : Colors.red).withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'LIVE' : 'OFFLINE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
