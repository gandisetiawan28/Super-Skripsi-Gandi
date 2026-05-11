import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/latihan_provider.dart';
import '../models/latihan_model.dart';
import '../providers/api_keys_provider.dart';
import 'package:intl/intl.dart';
import 'latihan_soal_page.dart';

class LatihanSetupPage extends ConsumerStatefulWidget {
  const LatihanSetupPage({super.key});

  @override
  ConsumerState<LatihanSetupPage> createState() => _LatihanSetupPageState();
}

class _LatihanSetupPageState extends ConsumerState<LatihanSetupPage> with TickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }
  
  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final file = result.files.first;
      ref.read(latihanSettingsProvider.notifier).updateFilePath(file.path!, file.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(latihanSettingsProvider);
    final apiKeys = ref.watch(apiKeysProvider);
    final history = ref.watch(latihanHistoryProvider);

    // Auto-select model logic moved to main build
    ref.listen<AsyncValue<List<String>>>(latihanModelsProvider, (previous, next) {
      if (next is AsyncData<List<String>> && next.value.isNotEmpty) {
        final currentModel = ref.read(latihanSettingsProvider).model;
        if (currentModel == null || !next.value.contains(currentModel)) {
          ref.read(latihanSettingsProvider.notifier).updateModel(next.value.first);
        }
      }
    });
    
    List<String> availableProviders = apiKeys.keys.toList();
    if (!availableProviders.contains('Google Gemini')) {
      availableProviders.add('Google Gemini');
    }
    availableProviders.sort();

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
                    top: 100 - (30 * _blobController.value),
                    right: -120 + (40 * _blobController.value),
                    child: _buildBlob(350, Colors.teal.withOpacity(0.04)),
                  ),
                  Positioned(
                    bottom: -50 + (40 * _blobController.value),
                    left: -100 + (30 * _blobController.value),
                    child: _buildBlob(400, GlassmorphismTheme.primaryRed.withOpacity(0.06)),
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
                _buildHeader(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (history.isNotEmpty) ...[
                        _buildProgressSection(history),
                        const SizedBox(height: 24),
                      ],
                      _buildUploadSection(settings),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Pengaturan Ujian'),
                      _buildLevelSelector(settings),
                      const SizedBox(height: 16),
                      _buildSoalSlider(settings),
                      const SizedBox(height: 16),
                      _buildBabSelector(settings),
                      const SizedBox(height: 16),
                      _buildPersonaSelector(settings),
                      const SizedBox(height: 16),
                      _buildAiConfig(settings, availableProviders),
                      const SizedBox(height: 160),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: _buildStartButton(settings),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latihan Skripsi',
              style: GoogleFonts.outfit(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: GlassmorphismTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Uji kesiapan sidang Anda dengan AI',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: GlassmorphismTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: GlassmorphismTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildProgressSection(List<LatihanHistoryItem> history) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: GlassmorphismTheme.primaryRed.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.auto_graph_rounded, color: GlassmorphismTheme.primaryRed, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Skor Terakhir', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500)),
                Text('${history.first.score.toInt()}%', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: GlassmorphismTheme.softShadow),
            child: Column(
              children: [
                Text('Sesi', style: GoogleFonts.inter(fontSize: 10, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
                Text('${history.length}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(LatihanSettings settings) {
    final hasFile = settings.filePath != null;
    return GestureDetector(
      onTap: _pickFile,
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        borderRadius: 28,
        backgroundColor: hasFile ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.5),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasFile ? Colors.green.withOpacity(0.1) : GlassmorphismTheme.primaryRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFile ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded, 
                size: 32, 
                color: hasFile ? Colors.green : GlassmorphismTheme.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              settings.namaFile ?? 'Pilih PDF Skripsi untuk Latihan',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: hasFile ? FontWeight.bold : FontWeight.w500,
                color: hasFile ? GlassmorphismTheme.textPrimary : GlassmorphismTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasFile)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Ganti File PDF', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSelector(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tingkat Kesulitan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLevelItem(LatihanLevel.level1, 'Dasar', settings.level == LatihanLevel.level1),
              const SizedBox(width: 10),
              _buildLevelItem(LatihanLevel.level2, 'Analisis', settings.level == LatihanLevel.level2),
              const SizedBox(width: 10),
              _buildLevelItem(LatihanLevel.level3, 'Kritis', settings.level == LatihanLevel.level3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelItem(LatihanLevel level, String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(latihanSettingsProvider.notifier).updateLevel(level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? GlassmorphismTheme.redGlowShadow : GlassmorphismTheme.softShadow,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : GlassmorphismTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoalSlider(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Soal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: GlassmorphismTheme.primaryRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${settings.jumlahSoal}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GlassmorphismTheme.primaryRed,
              thumbColor: GlassmorphismTheme.primaryRed,
              overlayColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
            ),
            child: Slider(
              value: settings.jumlahSoal.toDouble(),
              min: 5, max: 50, divisions: 9,
              onChanged: (v) => ref.read(latihanSettingsProvider.notifier).updateJumlahSoal(v.toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBabSelector(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bab yang Diujikan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: ['Semua', 'Bab 1', 'Bab 2', 'Bab 3', 'Bab 4', 'Bab 5'].map((bab) {
              final isSelected = settings.babDipilih.contains(bab);
              return GestureDetector(
                onTap: () {
                   final newList = List<String>.from(settings.babDipilih);
                   if (bab == 'Semua') {
                     newList.clear();
                     newList.add('Semua');
                   } else {
                     newList.remove('Semua');
                     if (!isSelected) newList.add(bab);
                     else if (newList.length > 1) newList.remove(bab);
                     if (newList.isEmpty) newList.add('Semua');
                   }
                   ref.read(latihanSettingsProvider.notifier).updateBabDipilih(newList);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected ? GlassmorphismTheme.redGlowShadow : GlassmorphismTheme.softShadow,
                  ),
                  child: Text(
                    bab,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : GlassmorphismTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaSelector(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Persona Dosen Penguji', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPersonaItem(PersonaDosen.ramah, '😊', 'Ramah', settings.persona == PersonaDosen.ramah),
              _buildPersonaItem(PersonaDosen.sedang, '📖', 'Standar', settings.persona == PersonaDosen.sedang),
              _buildPersonaItem(PersonaDosen.killer, '😈', 'Killer', settings.persona == PersonaDosen.killer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaItem(PersonaDosen persona, String emoji, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => ref.read(latihanSettingsProvider.notifier).updatePersona(persona),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isSelected ? GlassmorphismTheme.redGlowShadow : GlassmorphismTheme.softShadow,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiConfig(LatihanSettings settings, List<String> providers) {
    final modelsAsync = ref.watch(latihanModelsProvider);
    final apiKeys = ref.watch(apiKeysProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Configuration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: settings.provider,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'AI Provider',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary),
              filled: true,
              fillColor: Colors.black.withOpacity(0.02),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: providers.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
            onChanged: (val) => ref.read(latihanSettingsProvider.notifier).updateProvider(val!),
          ),
          if (settings.provider != null && (apiKeys[settings.provider!]?.length ?? 0) > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: settings.apiKeyName ?? apiKeys[settings.provider!]!.first['name'],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Pilih API Key (${settings.provider})',
                labelStyle: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary),
                filled: true,
                fillColor: Colors.black.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: apiKeys[settings.provider!]!.map((k) => DropdownMenuItem(
                value: k['name'], 
                child: Text(k['name'] ?? 'Untitled', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))
              )).toList(),
              onChanged: (val) => ref.read(latihanSettingsProvider.notifier).updateApiKeyName(val!),
            ),
          ],
          const SizedBox(height: 16),
          modelsAsync.when(
            data: (models) => DropdownButtonFormField<String>(
              value: models.contains(settings.model) ? settings.model : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Model Name',
                labelStyle: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary),
                filled: true,
                fillColor: Colors.black.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: models.map((m) => DropdownMenuItem(
                value: m, 
                child: Text(m, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))
              )).toList(),
              onChanged: (val) => ref.read(latihanSettingsProvider.notifier).updateModel(val!),
            ),
            loading: () => const Center(child: LinearProgressIndicator(color: GlassmorphismTheme.primaryRed)),
            error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(LatihanSettings settings) {
    final canStart = settings.filePath != null && settings.model != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: MediaQuery.of(context).size.width * 0.85,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: canStart ? GlassmorphismTheme.redGlowShadow : [],
      ),
      child: ElevatedButton(
        onPressed: canStart ? () {
          ref.read(latihanSessionProvider.notifier).startLatihan(settings);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LatihanSoalPage()),
          );
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canStart ? GlassmorphismTheme.primaryRed : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          'MULAI SIMULASI SIDANG',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
        ),
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
}
