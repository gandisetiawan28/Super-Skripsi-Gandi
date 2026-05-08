import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/latihan_provider.dart';
import '../models/latihan_model.dart';
import '../providers/api_keys_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'latihan_soal_page.dart';

class LatihanSetupPage extends ConsumerStatefulWidget {
  const LatihanSetupPage({super.key});

  @override
  ConsumerState<LatihanSetupPage> createState() => _LatihanSetupPageState();
}

class _LatihanSetupPageState extends ConsumerState<LatihanSetupPage> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _chartController;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _chartController.forward();
    });
  }

  @override
  void dispose() {
    _chartController.dispose();
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

  void _handleDrop(List<XFile> files) {
    if (files.isNotEmpty && files.first.path.endsWith('.pdf')) {
      final file = files.first;
      ref.read(latihanSettingsProvider.notifier).updateFilePath(file.path, file.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(latihanSettingsProvider);
    final apiKeys = ref.watch(apiKeysProvider);
    final history = ref.watch(latihanHistoryProvider);
    
    List<String> availableProviders = apiKeys.keys.toList();
    if (!availableProviders.contains('Google Gemini')) {
      availableProviders.add('Google Gemini');
    }
    availableProviders.sort();

    return Scaffold(
      extendBody: true, // Agar konten bisa masuk ke bawah navbar/floating button
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlassmorphismTheme.backgroundStart,
              GlassmorphismTheme.backgroundEnd,
            ],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (history.isNotEmpty) ...[
                    _buildProgressChart(history),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildUploadCard(settings),
                            const SizedBox(height: 16),
                            _buildLevelCard(settings),
                            const SizedBox(height: 16),
                            _buildSoalCard(settings),
                            const SizedBox(height: 16),
                            _buildBabCard(settings),
                            const SizedBox(height: 16),
                            _buildTimerCard(settings),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            if (history.isNotEmpty) ...[
                              _buildAiMentorCard(),
                              const SizedBox(height: 16),
                            ],
                            _buildHistorySection(history),
                            const SizedBox(height: 16),
                            _buildPersonaCard(settings),
                            const SizedBox(height: 16),
                            _buildAiConfigCard(settings, availableProviders),
                            const SizedBox(height: 120), // Memberi ruang untuk floating button
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // FLOATING ACTION BUTTON (Custom Stack)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100, // Di atas Navbar Bottom (asumsi Navbar tinggi ~80-90)
              child: Center(
                child: _buildFloatingStartButton(settings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latihan Skripsi',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: GlassmorphismTheme.textPrimary,
            letterSpacing: -1,
          ),
        ),
        Text(
          'Uji pemahaman skripsimu dengan simulasi tanya jawab AI',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: GlassmorphismTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart(List<LatihanHistoryItem> history) {
    final chartData = history.reversed.toList();
    if (chartData.length > 10) chartData.removeRange(0, chartData.length - 10);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24).copyWith(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
              const SizedBox(width: 8),
              Text('Statistik Perkembangan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${history.length} Sesi Latihan', style: const TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _chartController,
            builder: (context, child) {
              return SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                  painter: LineChartPainter(
                    scores: chartData.map((e) => e.score.toDouble()).toList(),
                    questions: chartData.map((e) => e.totalQuestions).toList(),
                    dates: chartData.map((e) => e.date).toList(),
                    levels: chartData.map((e) => e.settings.levelLabel).toList(),
                    lineColor: GlassmorphismTheme.primaryRed,
                    progress: _chartController.value,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiMentorCard() {
    final analysis = ref.watch(aiAnalysisProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      backgroundColor: GlassmorphismTheme.primaryRed.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
              const SizedBox(width: 8),
              Text('Mentor AI Insight', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(latihanHistoryProvider.notifier).analyzeProgress(ref),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: GlassmorphismTheme.primaryRed),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Refresh Analisis',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (analysis == null)
            InkWell(
              onTap: () => ref.read(latihanHistoryProvider.notifier).analyzeProgress(ref),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Klik untuk Analisis Progres',
                    style: TextStyle(fontSize: 12, color: GlassmorphismTheme.primaryRed, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          else
            Text(
              analysis,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: GlassmorphismTheme.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List<LatihanHistoryItem> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Riwayat Sesi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        if (history.isEmpty)
          const GlassCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Belum ada riwayat.', style: TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 13)),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: history.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final sequenceNumber = history.length - index;
                  return _buildHistoryCard(item, sequenceNumber);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryCard(LatihanHistoryItem item, int sequenceNumber) {
    // Format babDipilih jika kosong maka 'Semua'
    final babTitle = item.settings.babDipilih.isEmpty ? 'Semua Bab' : item.settings.babDipilih.join(', ');
    final title = 'Latihan $sequenceNumber - $babTitle - ${item.settings.levelLabel}';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${item.score}', style: const TextStyle(color: GlassmorphismTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${item.fileName} • ${item.totalQuestions} Soal', 
                  style: const TextStyle(fontSize: 11, color: GlassmorphismTheme.textSecondary)
                ),
                Text(
                  DateFormat('dd MMM yyyy • HH:mm').format(item.date),
                  style: TextStyle(fontSize: 10, color: GlassmorphismTheme.textSecondary.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(latihanHistoryProvider.notifier).deleteSingleHistory(item.id);
            },
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Hapus Riwayat',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              ref.read(latihanSessionProvider.notifier).viewHistoryResult(item);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LatihanSoalPage()));
            },
            icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.blueAccent, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Lihat Hasil Pengerjaan',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              ref.read(latihanSessionProvider.notifier).startFromHistory(item);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LatihanSoalPage()));
            },
            icon: const Icon(Icons.play_circle_outline, color: GlassmorphismTheme.primaryRed, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            tooltip: 'Kerjakan Ulang',
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(LatihanSettings settings) {
    return DropTarget(
      onDragDone: (detail) => _handleDrop(detail.files),
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: GlassCard(
        margin: EdgeInsets.zero,
        backgroundColor: _isDragging ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dokumen Skripsi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GlassmorphismTheme.borderGlass, width: 1.5),
                  color: Colors.black.withOpacity(0.02),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_rounded, size: 40, color: GlassmorphismTheme.primaryRed),
                    const SizedBox(height: 12),
                    Text(settings.namaFile ?? 'Klik untuk upload atau drag PDF', 
                      style: GoogleFonts.inter(fontSize: 14, color: settings.namaFile != null ? GlassmorphismTheme.textPrimary : GlassmorphismTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoalCard(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Soal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${settings.jumlahSoal}', style: const TextStyle(fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GlassmorphismTheme.primaryRed,
              inactiveTrackColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
              thumbColor: GlassmorphismTheme.primaryRed,
              trackHeight: 4,
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

  Widget _buildBabCard(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bab yang Diujikan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['Semua', 'Bab 1', 'Bab 2', 'Bab 3', 'Bab 4', 'Bab 5'].map((bab) {
              final isSelected = settings.babDipilih.contains(bab);
              return InkWell(
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      if (isSelected) const SizedBox(width: 4),
                      Text(bab, style: GoogleFonts.inter(
                        fontSize: 13, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tingkat Kesulitan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _levelRow(LatihanLevel.level1, 'Level 1: Dasar', '📝', settings.level == LatihanLevel.level1, 'Pemahaman fakta & teori'),
          const SizedBox(height: 8),
          _levelRow(LatihanLevel.level2, 'Level 2: Analisis', '🔍', settings.level == LatihanLevel.level2, 'Logika & metodologi'),
          const SizedBox(height: 8),
          _levelRow(LatihanLevel.level3, 'Level 3: Kritis', '⚔️', settings.level == LatihanLevel.level3, 'Pertahanan & skenario HOTS'),
        ],
      ),
    );
  }

  Widget _levelRow(LatihanLevel level, String label, String emoji, bool isSelected, String sub) {
    return InkWell(
      onTap: () => ref.read(latihanSettingsProvider.notifier).updateLevel(level),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass, width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(
                    fontSize: 14, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                    color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary
                  )),
                  Text(sub, style: GoogleFonts.inter(
                    fontSize: 10, 
                    color: isSelected ? Colors.white.withOpacity(0.8) : GlassmorphismTheme.textSecondary
                  )),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaCard(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Persona Dosen', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _personaRow(PersonaDosen.ramah, 'Dosen Ramah', '😊', settings.persona == PersonaDosen.ramah),
          const SizedBox(height: 8),
          _personaRow(PersonaDosen.sedang, 'Dosen Sedang', '📖', settings.persona == PersonaDosen.sedang),
          const SizedBox(height: 8),
          _personaRow(PersonaDosen.killer, 'Dosen Killer', '😈', settings.persona == PersonaDosen.killer),
        ],
      ),
    );
  }

  Widget _personaRow(PersonaDosen persona, String label, String emoji, bool isSelected) {
    return InkWell(
      onTap: () => ref.read(latihanSettingsProvider.notifier).updatePersona(persona),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass, width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(
              fontSize: 14, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
              color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAiConfigCard(LatihanSettings settings, List<String> providers) {
    final modelsAsync = ref.watch(latihanModelsProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('AI Configuration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (modelsAsync.isLoading)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GlassmorphismTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Provider', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: providers.map((p) {
              final isSelected = settings.provider == p;
              return InkWell(
                onTap: () => ref.read(latihanSettingsProvider.notifier).updateProvider(p),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
                  ),
                  child: Text(p, style: TextStyle(
                    fontSize: 12, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary
                  )),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),
          Text('Model (Auto-Key Rotation)', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            width: double.infinity,
            child: modelsAsync.maybeWhen(
              data: (models) {
                if (models.isEmpty) return const Text('Tidak ada model tersedia.', style: TextStyle(fontSize: 11, color: GlassmorphismTheme.textSecondary));
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: models.map((m) {
                    final isSelected = settings.model == m;
                    return InkWell(
                      onTap: () => ref.read(latihanSettingsProvider.notifier).updateModel(m),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
                        ),
                        child: Text(m, style: TextStyle(
                          fontSize: 11, 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary
                        )),
                      ),
                    );
                  }).toList(),
                );
              },
              orElse: () => settings.provider == null 
                  ? const Text('Pilih provider dahulu.', style: TextStyle(fontSize: 11, color: GlassmorphismTheme.textSecondary))
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(LatihanSettings settings) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Timer Pengerjaan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
              Switch(
                value: settings.timerAktif,
                activeColor: GlassmorphismTheme.primaryRed,
                onChanged: (v) => ref.read(latihanSettingsProvider.notifier).updateTimerAktif(v),
              ),
            ],
          ),
          if (settings.timerAktif) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: GlassmorphismTheme.primaryRed),
                const SizedBox(width: 8),
                Text('${settings.timerMenit} Menit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed)),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: GlassmorphismTheme.primaryRed,
                      inactiveTrackColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                      thumbColor: GlassmorphismTheme.primaryRed,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: settings.timerMenit.toDouble(),
                      min: 5, max: 120, divisions: 23,
                      onChanged: (v) => ref.read(latihanSettingsProvider.notifier).updateTimerMenit(v.toInt()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingStartButton(LatihanSettings settings) {
    final canStart = settings.filePath != null && settings.model != null;
    return AnimatedScale(
      scale: canStart ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 300,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: canStart ? [
            BoxShadow(color: GlassmorphismTheme.primaryRed.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
          ] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ElevatedButton(
            onPressed: canStart ? () {
              ref.read(latihanSessionProvider.notifier).startLatihan(settings);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LatihanSoalPage()));
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canStart ? GlassmorphismTheme.primaryRed : Colors.grey.withOpacity(0.2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded),
                const SizedBox(width: 12),
                Text('MULAI LATIHAN', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> scores;
  final List<int> questions;
  final List<DateTime> dates;
  final List<String> levels;
  final Color lineColor;
  final double progress;

  LineChartPainter({
    required this.scores, 
    required this.questions,
    required this.dates,
    required this.levels,
    required this.lineColor,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final double stepX = size.width / (scores.length > 1 ? scores.length - 1 : 1);
    
    final double verticalPadding = 25; // Padding atas & bawah agar teks tidak terpotong
    final double chartHeight = size.height - (verticalPadding * 2);
    
    for (int i = 0; i < scores.length; i++) {
      final double x = i * stepX;
      final double y = size.height - verticalPadding - (scores[i] / 100 * chartHeight);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw grid first
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double y = size.height - verticalPadding - (i / 4 * chartHeight);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw animated path
    final pathMetrics = path.computeMetrics().toList();
    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }

    // Draw dots and text only reached by progress
    for (int i = 0; i < scores.length; i++) {
      final double x = i * stepX;
      final double y = size.height - verticalPadding - (scores[i] / 100 * chartHeight);
      
      // Calculate at what progress this point should appear
      final double pointProgressThreshold = scores.length > 1 ? i / (scores.length - 1) : 0;
      
      if (progress >= pointProgressThreshold) {
        canvas.drawCircle(Offset(x, y), 3, dotPaint);

        // Draw score text (Selalu di atas titik)
        final scorePainter = TextPainter(
          text: TextSpan(
            text: scores[i].toInt().toString(),
            style: TextStyle(
              color: lineColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        scorePainter.layout();
        scorePainter.paint(canvas, Offset(x - (scorePainter.width / 2), y - 20));

        // Draw questions count and level (e.g. 10Q - L1)
        final levelNum = levels[i].replaceAll(RegExp(r'[^0-9]'), '');
        final qPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${questions[i]}Q',
                style: TextStyle(
                  color: GlassmorphismTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: ' - L$levelNum',
                style: TextStyle(
                  color: lineColor.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        );
        qPainter.layout();
        qPainter.paint(canvas, Offset(x - (qPainter.width / 2), y + 8));

        // Draw date & time (Sangat kecil di paling bawah area)
        final bool isFirstOfData = i == 0;
        final bool isFirstOfDay = !isFirstOfData && (dates[i].day != dates[i-1].day || dates[i].month != dates[i-1].month);
        
        // Selalu tampilkan jam, tapi tanggal hanya jika awal data atau ganti hari
        final bool isNewDay = isFirstOfData || isFirstOfDay;
        
        final datePainter = TextPainter(
          text: TextSpan(
            style: TextStyle(
              fontSize: 7,
              color: GlassmorphismTheme.textSecondary.withOpacity(0.4),
            ),
            children: [
              if (isNewDay)
                TextSpan(
                  text: '${DateFormat('dd/MM').format(dates[i])} ',
                  style: TextStyle(
                    color: lineColor.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              TextSpan(
                text: DateFormat('HH:mm').format(dates[i]),
                style: TextStyle(
                  fontWeight: isNewDay ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
        );
        datePainter.layout();
        datePainter.paint(canvas, Offset(x - (datePainter.width / 2), size.height + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
