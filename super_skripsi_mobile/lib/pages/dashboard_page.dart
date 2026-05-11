import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/onboarding_provider.dart';
import '../providers/documents_provider.dart';
import '../providers/latihan_provider.dart';
import '../providers/research_blueprint_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> with TickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(onboardingProvider);
    final docsAsync = ref.watch(documentsProvider);
    final history = ref.watch(latihanHistoryProvider);
    final blueprint = ref.watch(researchBlueprintProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          // ── Background Blobs ──
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -80 + (40 * _blobController.value),
                    right: -100 + (20 * _blobController.value),
                    child: _buildBlob(350, GlassmorphismTheme.primaryRed.withOpacity(0.08)),
                  ),
                  Positioned(
                    bottom: 100 - (30 * _blobController.value),
                    left: -120 + (50 * _blobController.value),
                    child: _buildBlob(300, Colors.blue.withOpacity(0.06)),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ──
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(user),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 10),
                      _buildProgressOverview(blueprint),
                      const SizedBox(height: 24),
                      _buildStatsRow(docsAsync, history),
                      const SizedBox(height: 32),
                      _buildQuickActions(context),
                      const SizedBox(height: 32),
                      _buildRecentHistoryCard(history),
                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(OnboardingState user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${user.googleName?.split(' ').first ?? "Pejuang"}! 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GlassmorphismTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Siap lanjut riset hari ini?',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: GlassmorphismTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.2)),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                backgroundImage: user.googlePhotoUrl != null ? NetworkImage(user.googlePhotoUrl!) : null,
                child: user.googlePhotoUrl == null 
                  ? const Icon(Icons.person_rounded, color: GlassmorphismTheme.primaryRed) 
                  : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverview(ResearchBlueprintState blueprint) {
    int totalChapters = blueprint.structure.length;
    int filledChapters = blueprint.structure.where((c) => c.title.isNotEmpty).length;
    double progress = totalChapters > 0 ? filledChapters / totalChapters : 0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progres Blueprint',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: GlassmorphismTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$filledChapters dari $totalChapters Bab telah dirancang.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: GlassmorphismTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                    color: GlassmorphismTheme.primaryRed,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: GlassmorphismTheme.primaryRed,
                  backgroundColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AsyncValue<List<dynamic>> docsAsync, List<dynamic> history) {
    final docCount = docsAsync.when(data: (d) => d.length, loading: () => 0, error: (_, __) => 0);
    final lastScore = history.isNotEmpty ? history.first.score.toInt() : 0;

    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            'Koleksi Riset',
            '$docCount PDF',
            Icons.library_books_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniStatCard(
            'Skor Terakhir',
            history.isEmpty ? '-' : '$lastScore%',
            Icons.bolt_rounded,
            Colors.amber.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: GlassmorphismTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Aksi Cepat',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton('Riset', Icons.add_to_photos_rounded, Colors.indigo),
            _buildActionButton('Latihan', Icons.quiz_rounded, Colors.teal),
            _buildActionButton('Blueprint', Icons.architecture_rounded, Colors.orange),
            _buildActionButton('Chat AI', Icons.psychology_rounded, GlassmorphismTheme.primaryRed),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: GlassmorphismTheme.softShadow,
            border: Border.all(color: Colors.white),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GlassmorphismTheme.textPrimary.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentHistoryCard(List<dynamic> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Aktivitas Terbaru',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (history.isEmpty)
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            margin: EdgeInsets.zero,
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_rounded, size: 48, color: GlassmorphismTheme.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat latihan.',
                    style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ...history.take(3).map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(dynamic item) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${item.score.toInt()}',
                style: GoogleFonts.outfit(
                  color: GlassmorphismTheme.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GlassmorphismTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.correctAnswers}/${item.totalQuestions} Benar • ${item.date.toString().substring(0, 10)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: GlassmorphismTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: GlassmorphismTheme.textSecondary.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
