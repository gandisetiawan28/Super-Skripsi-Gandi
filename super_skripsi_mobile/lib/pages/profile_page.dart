import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/onboarding_provider.dart';
import '../services/sync_service.dart';
import 'api_keys_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with TickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
    final syncState = ref.watch(syncProvider);

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
                    top: -50 + (25 * _blobController.value),
                    right: -100 + (30 * _blobController.value),
                    child: _buildBlob(380, Colors.purple.withOpacity(0.04)),
                  ),
                  Positioned(
                    bottom: 100 - (35 * _blobController.value),
                    left: -80 + (45 * _blobController.value),
                    child: _buildBlob(350, GlassmorphismTheme.primaryRed.withOpacity(0.05)),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  _buildHeader(user),
                  const SizedBox(height: 40),
                  _buildSyncCard(ref, syncState),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Pengaturan Aplikasi'),
                  _buildSettingsList(context, ref),
                  const SizedBox(height: 40),
                  _buildLogoutButton(ref),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 16),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GlassmorphismTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(OnboardingState user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: GlassmorphismTheme.softShadow,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(55),
                child: user.googlePhotoUrl != null 
                  ? Image.network(user.googlePhotoUrl!, fit: BoxFit.cover)
                  : Container(
                      color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                      child: const Icon(Icons.person_rounded, size: 60, color: GlassmorphismTheme.primaryRed),
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          user.googleName ?? 'Gandi User',
          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          user.googleEmail ?? 'not_logged_in@gmail.com',
          style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSyncCard(WidgetRef ref, SyncState syncState) {
    final isSyncing = syncState.status == SyncStatus.syncing;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: GlassmorphismTheme.softShadow,
      ),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(24),
        borderRadius: 28,
        backgroundColor: Colors.white.withOpacity(0.85),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.cloud_sync_rounded, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google Drive Sync', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: GlassmorphismTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        isSyncing 
                          ? (syncState.message ?? 'Menghubungkan...') 
                          : 'Terakhir: ${syncState.lastSync != null ? DateFormat('dd MMM, HH:mm').format(syncState.lastSync!) : "Belum pernah"}',
                        style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isSyncing)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue))
                else
                  IconButton(
                    onPressed: () => ref.read(syncProvider.notifier).syncAll(),
                    icon: const Icon(Icons.refresh_rounded, color: GlassmorphismTheme.textPrimary),
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.05)),
                  ),
              ],
            ),
            if (syncState.status == SyncStatus.error)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(syncState.error ?? 'Gagal sinkron', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildSettingItem(Icons.key_rounded, 'API Key Manager', 'Kelola kunci Gemini, Groq, & OpenAI', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ApiKeysPage()));
        }),
        _buildSettingItem(Icons.color_lens_rounded, 'Tema & Estetika', 'Kustomisasi tampilan aplikasi', () {}),
        _buildSettingItem(Icons.info_outline_rounded, 'Tentang Super Skripsi', 'Versi 1.1.0 Premium Mobile', () {}),
        _buildSettingItem(Icons.help_outline_rounded, 'Pusat Bantuan', 'Panduan penggunaan fitur AI', () {}),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        borderRadius: 20,
        backgroundColor: Colors.white.withOpacity(0.6),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: GlassmorphismTheme.textPrimary, size: 20),
          ),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: GlassmorphismTheme.textPrimary)),
          subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: GlassmorphismTheme.textSecondary)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: TextButton.icon(
        onPressed: () => ref.read(onboardingProvider.notifier).resetOnboarding(),
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: Text('KELUAR DARI AKUN', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      ),
    );
  }
}
