import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/research_blueprint_provider.dart';
import '../providers/api_keys_provider.dart';
import '../providers/latihan_provider.dart'; // Reusing modelFetchServiceProvider
import '../services/ai_extraction_service.dart';
import '../services/pdf_service.dart';
import '../prompts/blueprint_generation_prompt.dart';

class BlueprintPage extends ConsumerStatefulWidget {
  const BlueprintPage({super.key});

  @override
  ConsumerState<BlueprintPage> createState() => _BlueprintPageState();
}

class _BlueprintPageState extends ConsumerState<BlueprintPage> {
  late TextEditingController _judulController;
  late TextEditingController _lokasiController;
  late TextEditingController _populationController;
  bool _isAnalyzing = false;
  String _statusMsg = '';

  // Local UI State for Models (since it depends on network)
  List<String> _availableModels = [];
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    final blueprint = ref.read(researchBlueprintProvider);
    _judulController = TextEditingController(text: blueprint.judul);
    _lokasiController = TextEditingController(text: blueprint.lokasi);
    _populationController = TextEditingController(text: blueprint.populationCount?.toString() ?? '');
    
    // Load models for the already saved provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchModels();
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _lokasiController.dispose();
    _populationController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    final blueprint = ref.read(researchBlueprintProvider);
    if (blueprint.selectedProvider == null) return;

    setState(() => _isLoadingModels = true);
    try {
      final fetchService = ref.read(modelFetchServiceProvider);
      final apiKeys = ref.read(apiKeysProvider);
      
      String? actualKey;
      final keysForProvider = apiKeys[blueprint.selectedProvider!] ?? [];
      if (keysForProvider.isNotEmpty) {
        actualKey = keysForProvider.first['key'];
      }

      final models = await fetchService.fetchModels(blueprint.selectedProvider!, apiKey: actualKey);
      setState(() {
        _availableModels = models;
        // If saved model is not in the new list, or no model is saved, auto-select
        if (blueprint.selectedModel == null || !models.contains(blueprint.selectedModel)) {
           String? nextModel;
           if (blueprint.selectedProvider == 'Google Gemini' && models.contains('gemini-1.5-flash')) {
             nextModel = 'gemini-1.5-flash';
           } else if (models.isNotEmpty) {
             nextModel = models.first;
           }
           if (nextModel != null) {
             ref.read(researchBlueprintProvider.notifier).updateAIConfig(model: nextModel);
           }
        }
      });
    } catch (e) {
      debugPrint('Error fetching models: $e');
    } finally {
      setState(() => _isLoadingModels = false);
    }
  }

  Future<void> _pickGuideline() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      ref.read(researchBlueprintProvider.notifier).updateGuidelinePath(result.files.single.path);
    }
  }

  Future<void> _generateWithAI() async {
    final blueprint = ref.read(researchBlueprintProvider);
    if (blueprint.judul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan isi judul penelitian terlebih dahulu.')),
      );
      return;
    }

    if (blueprint.selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih model AI terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusMsg = 'Membaca pedoman PDF...';
    });

    try {
      String guidelineText = "";
      if (blueprint.guidelinePath != null) {
        final pdfService = PdfService();
        guidelineText = await pdfService.extractText(blueprint.guidelinePath!);
        if (guidelineText.length > 15000) {
          guidelineText = guidelineText.substring(0, 15000);
        }
      }

      setState(() => _statusMsg = 'Merancang kerangka skripsi (${blueprint.selectedProvider})...');

      final aiService = AiExtractionService(ref.read(apiKeyServiceProvider));
      
      final prompt = BlueprintGenerationPrompt.build(
        judul: blueprint.judul,
        lokasi: blueprint.lokasi,
        guidelineText: guidelineText,
        populationType: blueprint.populationType,
        populationCount: blueprint.populationCount,
      );

      final response = await aiService.extractCustom(
        systemPrompt: "You are a Research Architect. Always respond in valid JSON.",
        userText: prompt,
        provider: blueprint.selectedProvider!,
        model: blueprint.selectedModel!,
        isJson: true,
      );

      final decoded = jsonDecode(response);
      final String? aiThinking = decoded['thinking'];
      final List<dynamic> structJson = decoded['structure'];
      
      final List<ChapterBlueprint> newStructure = structJson.map((j) {
        return ChapterBlueprint(
          id: DateTime.now().millisecondsSinceEpoch.toString() + (structJson.indexOf(j)).toString(),
          babLabel: j['babLabel'],
          title: j['title'],
          subChapters: List<String>.from(j['subChapters']),
        );
      }).toList();

      ref.read(researchBlueprintProvider.notifier).setFullStructure(newStructure);
      
      // Show AI thinking in a dialog
      if (aiThinking != null && aiThinking.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFFFAF8F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: GlassmorphismTheme.primaryRed, size: 28),
                const SizedBox(width: 12),
                Text('AI Thinking Process', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  aiThinking,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.6, color: GlassmorphismTheme.textPrimary),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Mengerti', style: TextStyle(color: GlassmorphismTheme.primaryRed, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Kerangka skripsi berhasil dirancang otomatis!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal generate: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
        _statusMsg = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blueprint = ref.watch(researchBlueprintProvider);
    final apiKeys = ref.watch(apiKeysProvider);
    
    // Listen for initial load from Hive to update controllers
    ref.listen(researchBlueprintProvider, (previous, next) {
      if (previous == null || (previous.judul.isEmpty && next.judul.isNotEmpty)) {
        if (_judulController.text.isEmpty) {
          _judulController.text = next.judul;
        }
      }
      if (previous == null || (previous.lokasi.isEmpty && next.lokasi.isNotEmpty)) {
        if (_lokasiController.text.isEmpty) {
          _lokasiController.text = next.lokasi;
        }
      }
      if (previous?.populationCount != next.populationCount) {
        if (_populationController.text != (next.populationCount?.toString() ?? '')) {
          _populationController.text = next.populationCount?.toString() ?? '';
        }
      }
    });

    List<String> availableProviders = apiKeys.keys.toList();
    if (!availableProviders.contains('Google Gemini')) availableProviders.add('Google Gemini');
    availableProviders.sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildGuidelineSection(blueprint),
                    const SizedBox(height: 16),
                    _buildMainInfoSection(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _buildAiConfigCard(blueprint, availableProviders),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildStructureHeader(),
          const SizedBox(height: 16),
          ...blueprint.structure.map((chapter) => _ChapterCard(chapter: chapter)).toList(),
          const SizedBox(height: 16),
          _buildAddChapterButton(),
          const SizedBox(height: 40),
          _buildAIGuidanceNote(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.architecture_rounded, size: 16, color: GlassmorphismTheme.primaryRed),
              const SizedBox(width: 8),
              Text(
                'RESEARCH ARCHITECT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: GlassmorphismTheme.primaryRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Research Blueprint',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: GlassmorphismTheme.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rancang fondasi skripsi Anda secara otomatis dengan bantuan AI.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: GlassmorphismTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAiConfigCard(ResearchBlueprintState state, List<String> providers) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
              const SizedBox(width: 12),
              Text(
                'AI Configuration',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: GlassmorphismTheme.textPrimary),
              ),
              const Spacer(),
              if (_isLoadingModels)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GlassmorphismTheme.primaryRed)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Provider', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: providers.map((p) {
              final isSelected = state.selectedProvider == p;
              return InkWell(
                onTap: () {
                  ref.read(researchBlueprintProvider.notifier).updateAIConfig(provider: p, model: null);
                  _fetchModels();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
                  ),
                  child: Text(p, style: TextStyle(
                    fontSize: 11, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Model', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            width: double.infinity,
            child: _availableModels.isEmpty
                ? Text(_isLoadingModels ? 'Loading models...' : 'Tidak ada model tersedia.', style: const TextStyle(fontSize: 11, color: GlassmorphismTheme.textSecondary))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availableModels.map((m) {
                      final isSelected = state.selectedModel == m;
                      return InkWell(
                        onTap: () => ref.read(researchBlueprintProvider.notifier).updateAIConfig(model: m),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
                          ),
                          child: Text(m, style: TextStyle(
                            fontSize: 10, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary
                          )),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineSection(ResearchBlueprintState state) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
              const SizedBox(width: 12),
              Text(
                'Pedoman Kampus (Opsional)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: GlassmorphismTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _isAnalyzing ? null : _pickGuideline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: state.guidelinePath != null ? GlassmorphismTheme.primaryRed.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.guidelinePath != null ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                          size: 18,
                          color: state.guidelinePath != null ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.guidelinePath != null 
                              ? state.guidelinePath!.split('\\').last.split('/').last
                              : 'Pilih File PDF Pedoman...',
                            style: TextStyle(
                              color: state.guidelinePath != null ? GlassmorphismTheme.textPrimary : GlassmorphismTheme.textSecondary,
                              fontSize: 13,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (state.guidelinePath != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => ref.read(researchBlueprintProvider.notifier).updateGuidelinePath(null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _generateWithAI,
                icon: _isAnalyzing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Generate with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          if (_isAnalyzing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '⏳ $_statusMsg',
                style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.primaryRed, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainInfoSection() {
    final blueprint = ref.watch(researchBlueprintProvider);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildSimpleInput(
                label: 'Judul Utama Penelitian',
                controller: _judulController,
                hint: 'Masukkan judul skripsi lengkap Anda...',
                icon: Icons.title_rounded,
                maxLines: 2,
                onChanged: (val) => ref.read(researchBlueprintProvider.notifier).updateJudul(val),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildSimpleInput(
                label: 'Lokasi & Objek',
                controller: _lokasiController,
                hint: 'Contoh: PT. Maju Jaya, Jakarta...',
                icon: Icons.location_on_rounded,
                onChanged: (val) => ref.read(researchBlueprintProvider.notifier).updateLokasi(val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPopulationSection(blueprint),
      ],
    );
  }

  Widget _buildPopulationSection(ResearchBlueprintState blueprint) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded, size: 16, color: GlassmorphismTheme.textSecondary),
              const SizedBox(width: 8),
              Text('Populasi Penelitian', style: GoogleFonts.inter(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPopTypeChip(
                label: '♾️  Tidak Terbatas (Infinite)',
                isSelected: blueprint.populationType == 'infinite',
                onTap: () => ref.read(researchBlueprintProvider.notifier).updatePopulation(type: 'infinite'),
              ),
              _buildPopTypeChip(
                label: '📊  Terbatas (Finite)',
                isSelected: blueprint.populationType == 'finite',
                onTap: () => ref.read(researchBlueprintProvider.notifier).updatePopulation(type: 'finite'),
              ),
              if (blueprint.populationType == 'finite') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 200,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: _populationController,
                    onChanged: (v) {
                      final count = int.tryParse(v);
                      ref.read(researchBlueprintProvider.notifier).updatePopulation(
                        type: 'finite', 
                        count: count
                      );
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Jumlah populasi...',
                      hintStyle: TextStyle(color: GlassmorphismTheme.textSecondary.withOpacity(0.4), fontSize: 12),
                      prefixIcon: const Icon(Icons.tag, size: 16, color: GlassmorphismTheme.primaryRed),
                      suffixText: 'orang',
                      suffixStyle: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.05),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            blueprint.populationType == 'infinite'
              ? 'AI akan menggunakan rumus Lemeshow/Hair untuk menentukan sampel.'
              : 'AI akan menggunakan rumus Slovin untuk menentukan sampel.',
            style: GoogleFonts.inter(fontSize: 11, color: GlassmorphismTheme.textSecondary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPopTypeChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.borderGlass),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary,
        )),
      ),
    );
  }


  Widget _buildStructureHeader() {
    return Row(
      children: [
        const Icon(Icons.account_tree_rounded, color: GlassmorphismTheme.textPrimary, size: 20),
        const SizedBox(width: 12),
        Text(
          'Struktur Variabel & Bab',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GlassmorphismTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddChapterButton() {
    return InkWell(
      onTap: () => ref.read(researchBlueprintProvider.notifier).addChapter(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.3), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
          color: GlassmorphismTheme.primaryRed.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: GlassmorphismTheme.primaryRed, size: 24),
            const SizedBox(width: 12),
            Text(
              'Tambah Bab Baru',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GlassmorphismTheme.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: GlassmorphismTheme.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: GlassmorphismTheme.textSecondary.withOpacity(0.4), fontSize: 13),
              filled: true,
              fillColor: Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIGuidanceNote() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips Navigasi Blueprint',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tekan TAB untuk mengganti level penomoran (siklus 0-7).\n• Tekan BACKSPACE di awal baris untuk menurunkan level heading.\n• Penomoran akan otomatis bertambah saat Anda menekan ENTER.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.amber.shade900.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends ConsumerStatefulWidget {
  final ChapterBlueprint chapter;
  const _ChapterCard({required this.chapter});

  @override
  ConsumerState<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends ConsumerState<_ChapterCard> {
  late TextEditingController _babLabelController;
  late TextEditingController _titleController;
  late TextEditingController _subChaptersController;
  final FocusNode _subChaptersFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _babLabelController = TextEditingController(text: widget.chapter.babLabel);
    _titleController = TextEditingController(text: widget.chapter.title);
    
    String initialText = widget.chapter.subChapters.join("\n");
    if (initialText.isEmpty) {
      initialText = _generateNumber(0, 1, _extractBabNum());
    }
    _subChaptersController = TextEditingController(text: initialText);

    // Ensure numbering is applied on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recalculateAll();
      }
    });
  }

  int _extractBabNum() {
    String label = _babLabelController.text.toUpperCase();
    // Try Roman numerals (Longest first to avoid partial matches)
    if (label.contains('VIII')) return 8;
    if (label.contains('VII')) return 7;
    if (label.contains('III')) return 3;
    if (label.contains('VI')) return 6;
    if (label.contains('IV')) return 4;
    if (label.contains('IX')) return 9;
    if (label.contains('II')) return 2;
    if (label.contains('X')) return 10;
    if (label.contains('V')) return 5;
    if (label.contains('I')) return 1;

    final babMatch = RegExp(r'\d+').firstMatch(label);
    return babMatch != null ? (int.tryParse(babMatch.group(0)!) ?? 1) : 1;
  }

  @override
  void didUpdateWidget(_ChapterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.babLabel != widget.chapter.babLabel) {
       _babLabelController.text = widget.chapter.babLabel;
       _recalculateAll();
    }
    // Update content if changed by AI (check cleaned text to avoid loops)
    String newSubsText = widget.chapter.subChapters.join("\n");
    String currentCleanText = _subChaptersController.text.split('\n').map((l) => _getCleanContent(l)).join('\n');
    
    if (newSubsText.trim() != currentCleanText.trim()) {
       final selection = _subChaptersController.selection;
       _subChaptersController.value = _subChaptersController.value.copyWith(
         text: newSubsText,
         selection: selection.copyWith(
           baseOffset: selection.baseOffset.clamp(0, newSubsText.length),
           extentOffset: selection.extentOffset.clamp(0, newSubsText.length),
         ),
       );
       _recalculateAll(); 
    }
    if (widget.chapter.title != _titleController.text) {
       _titleController.text = widget.chapter.title;
    }
  }

  @override
  void dispose() {
    _babLabelController.dispose();
    _titleController.dispose();
    _subChaptersController.dispose();
    _subChaptersFocus.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _processTabCycle();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _processEnterKey();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _processBackspace();
      }
    }
  }

  void _processTabCycle() {
    final text = _subChaptersController.text;
    final selection = _subChaptersController.selection;
    if (selection.start < 0) return;

    final lines = text.split(RegExp(r'\r?\n'));
    int currentLineIndex = _findCurrentLineIndex(lines, selection.start);
    String currentLine = lines[currentLineIndex];

    int currentIndent = RegExp(r'^ *').stringMatch(currentLine)?.length ?? 0;
    int currentLevel = (currentIndent / 2).floor();
    
    int prevLevel = 0;
    if (currentLineIndex > 0) {
      int prevIndent = RegExp(r'^ *').stringMatch(lines[currentLineIndex - 1])?.length ?? 0;
      prevLevel = (prevIndent / 2).floor();
    }

    int nextLevel = (currentLevel + 1);
    if (nextLevel > prevLevel + 1) nextLevel = 0; 
    if (nextLevel > 7) nextLevel = 0; 
    
    String cleanContent = _getCleanContent(currentLine);
    lines[currentLineIndex] = ("  " * nextLevel) + cleanContent;

    final newText = _recalculateNumbering(lines.join("\n"));
    _updateTextAndSync(newText);
  }

  void _processBackspace() {
    final text = _subChaptersController.text;
    final selection = _subChaptersController.selection;
    if (selection.start <= 0) return;

    final lines = text.split(RegExp(r'\r?\n'));
    int currentLineIndex = _findCurrentLineIndex(lines, selection.start);
    String currentLine = lines[currentLineIndex];
    int indent = RegExp(r'^ *').stringMatch(currentLine)?.length ?? 0;
    
    int startOfLineOffset = 0;
    for (int i = 0; i < currentLineIndex; i++) {
       startOfLineOffset += lines[i].length + 1;
    }
    int relativePos = selection.start - startOfLineOffset;

    if (relativePos <= indent + 5) { 
      if (indent >= 2) {
        String cleanContent = _getCleanContent(currentLine);
        lines[currentLineIndex] = ("  " * ((indent / 2).floor() - 1)) + cleanContent;
        final newText = _recalculateNumbering(lines.join("\n"));
        _updateTextAndSync(newText);
      }
    }
  }

  void _processEnterKey() {
    final text = _subChaptersController.text;
    final selection = _subChaptersController.selection;
    
    final lines = text.split(RegExp(r'\r?\n'));
    int currentLineIndex = _findCurrentLineIndex(lines, selection.start);
    int indent = RegExp(r'^ *').stringMatch(lines[currentLineIndex])?.length ?? 0;
    
    String prefix = " " * indent;
    final newText = text.replaceRange(selection.start, selection.end, "\n$prefix");
    
    final finalText = _recalculateNumbering(newText);
    _updateTextAndSync(finalText);
  }

  void _updateTextAndSync(String newText) {
    final selection = _subChaptersController.selection;
    _subChaptersController.value = _subChaptersController.value.copyWith(
      text: newText,
      selection: selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, newText.length),
        extentOffset: selection.extentOffset.clamp(0, newText.length),
      ),
    );
    _syncWithProvider(newText);
  }

  void _recalculateAll() {
    final selection = _subChaptersController.selection;
    final newText = _recalculateNumbering(_subChaptersController.text);
    
    // Use value.copyWith to preserve selection as much as possible
    _subChaptersController.value = _subChaptersController.value.copyWith(
      text: newText,
      selection: selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, newText.length),
        extentOffset: selection.extentOffset.clamp(0, newText.length),
      ),
    );
    _syncWithProvider(newText);
  }

  String _getCleanContent(String line) {
    final pattern = RegExp(r'^\s*([A-Z]\.\s+|[0-9]{1,2}(\.[0-9]{1,2}){0,7}\.?\s+|[a-z]\.\s+|[0-9a-z]\)\s+|\([0-9a-z]\)\s+|-\s+)');
    return line.replaceFirst(pattern, '').trim();
  }

  int _findCurrentLineIndex(List<String> lines, int cursor) {
    int charCount = 0;
    for (int i = 0; i < lines.length; i++) {
      charCount += lines[i].length + (i == lines.length - 1 ? 0 : 1);
      if (charCount >= cursor) return i;
    }
    return lines.length - 1;
  }

  String _toAlpha(int n) => String.fromCharCode(64 + (n > 26 ? 26 : n));
  String _toSmallAlpha(int n) => String.fromCharCode(96 + (n > 26 ? 26 : n));

  String _generateNumber(int level, int counter, int babNum, {List<int>? allCounters}) {
    if (widget.chapter.style == NumberingStyle.numeric) {
      List<String> parts = ["$babNum"];
      if (allCounters != null) {
        for (int l = 0; l <= level; l++) parts.add("${allCounters[l]}");
      } else {
        parts.add("$counter");
      }
      return "${parts.join(".")}. ";
    } else {
      switch (level) {
        case 0: return "${_toAlpha(counter)}. ";
        case 1: return "$counter. ";
        case 2: return "${_toSmallAlpha(counter)}. ";
        case 3: return "$counter) ";
        default: return "- ";
      }
    }
  }

  String _recalculateNumbering(String rawText) {
    List<String> rawLines = rawText.split(RegExp(r'\r?\n'));
    List<int> counters = [0, 0, 0, 0, 0, 0, 0, 0];
    int babNum = _extractBabNum();

    List<String> resultLines = [];
    bool firstContentFound = false;

    for (int i = 0; i < rawLines.length; i++) {
      String line = rawLines[i].trimRight();
      String content = _getCleanContent(line);
      
      if (content.isEmpty && i < rawLines.length - 1) continue;

      int spaceCount = RegExp(r'^ *').stringMatch(line)?.length ?? 0;
      int level = (spaceCount / 2).floor();
      if (level > 7) level = 7;

      for (int l = level + 1; l < counters.length; l++) counters[l] = 0;
      
      for (int l = 0; l <= level; l++) if (counters[l] == 0) counters[l] = 1;
      counters[level]++;

      if (resultLines.isEmpty && level == 0) counters[0] = 1;

      String numbering = _generateNumber(level, counters[level], babNum, allCounters: counters);
      resultLines.add(("  " * level) + numbering + content);
    }
    return resultLines.join("\n");
  }

  void _syncWithProvider(String text) {
    final subs = text.split(RegExp(r'\r?\n')).where((e) => _getCleanContent(e).isNotEmpty).toList();
    Future.microtask(() {
      if (mounted) {
        ref.read(researchBlueprintProvider.notifier).updateChapter(widget.chapter.id, subChapters: subs);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _babLabelController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: GlassmorphismTheme.primaryRed),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Bab 1'),
                    onChanged: (v) {
                      ref.read(researchBlueprintProvider.notifier).updateChapter(widget.chapter.id, babLabel: v);
                      _recalculateAll();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: GlassmorphismTheme.textPrimary),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Judul Bab'),
                    onChanged: (v) => ref.read(researchBlueprintProvider.notifier).updateChapter(widget.chapter.id, title: v),
                  ),
                ),
                _buildStyleToggle(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: GlassmorphismTheme.error, size: 20),
                  onPressed: () => ref.read(researchBlueprintProvider.notifier).removeChapter(widget.chapter.id),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.black12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, size: 14, color: GlassmorphismTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('SUB-BAB / VARIABEL PENELITIAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: GlassmorphismTheme.textSecondary, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.tab) {
                        _processTabCycle();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        _processEnterKey();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.backspace) {
                        _processBackspace();
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _subChaptersController,
                    focusNode: _subChaptersFocus,
                    maxLines: null,
                    style: GoogleFonts.firaCode(fontSize: 13, color: GlassmorphismTheme.textPrimary, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Tulis sub-bab...',
                      hintStyle: TextStyle(color: GlassmorphismTheme.textSecondary.withOpacity(0.4), fontSize: 13),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (v) => _syncWithProvider(v), 
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleToggle() {
    final bool isNumeric = widget.chapter.style == NumberingStyle.numeric;
    return InkWell(
      onTap: () {
        final newStyle = isNumeric ? NumberingStyle.mixed : NumberingStyle.numeric;
        ref.read(researchBlueprintProvider.notifier).updateChapter(widget.chapter.id, style: newStyle);
        _recalculateAll();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isNumeric ? Icons.format_list_numbered_rounded : Icons.format_list_bulleted_rounded, 
                 size: 14, color: GlassmorphismTheme.primaryRed),
            const SizedBox(width: 6),
            Text(
              isNumeric ? '1.1 Style' : 'A. Style',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed),
            ),
          ],
        ),
      ),
    );
  }
}
