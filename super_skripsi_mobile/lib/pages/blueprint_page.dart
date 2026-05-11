import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/research_blueprint_provider.dart';
import '../providers/latihan_provider.dart'; // For modelFetchServiceProvider
import '../providers/api_keys_provider.dart';
import '../services/ai_extraction_service.dart';
import '../services/pdf_service.dart';
import '../prompts/blueprint_generation_prompt.dart';

class BlueprintPage extends ConsumerStatefulWidget {
  const BlueprintPage({super.key});

  @override
  ConsumerState<BlueprintPage> createState() => _BlueprintPageState();
}

class _BlueprintPageState extends ConsumerState<BlueprintPage> with TickerProviderStateMixin {
  late TextEditingController _judulController;
  late TextEditingController _lokasiController;
  bool _isAnalyzing = false;
  String _statusMsg = '';
  List<String> _availableModels = [];
  bool _isLoadingModels = false;
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    final blueprint = ref.read(researchBlueprintProvider);
    _judulController = TextEditingController(text: blueprint.judul);
    _lokasiController = TextEditingController(text: blueprint.lokasi);
    
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchModels();
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _lokasiController.dispose();
    _blobController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi judul penelitian Anda dulu!'), behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusMsg = 'Membaca pedoman...';
    });

    try {
      String guidelineText = "";
      if (blueprint.guidelinePath != null) {
        guidelineText = await PdfService().extractText(blueprint.guidelinePath!);
      }

      setState(() => _statusMsg = 'Merancang skripsi...');
      final aiService = AiExtractionService(ref.read(apiKeyServiceProvider));
      
      final prompt = BlueprintGenerationPrompt.build(
        judul: blueprint.judul,
        lokasi: blueprint.lokasi,
        guidelineText: guidelineText,
        populationType: blueprint.populationType,
        populationCount: blueprint.populationCount,
      );

      final response = await aiService.extractCustom(
        systemPrompt: "Research Architect JSON Mode",
        userText: prompt,
        provider: blueprint.selectedProvider!,
        model: blueprint.selectedModel!,
        isJson: true,
      );

      final decoded = jsonDecode(response);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Blueprint berhasil dibuat!'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), behavior: SnackBarBehavior.floating));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blueprint = ref.watch(researchBlueprintProvider);
    final apiKeys = ref.watch(apiKeysProvider);

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
                    top: -50 + (20 * _blobController.value),
                    left: -80 + (40 * _blobController.value),
                    child: _buildBlob(350, Colors.orange.withOpacity(0.04)),
                  ),
                  Positioned(
                    bottom: 50 - (30 * _blobController.value),
                    right: -100 + (50 * _blobController.value),
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
                _buildAppBar(blueprint),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildHeaderInfo(blueprint),
                        const SizedBox(height: 24),
                        _buildAiConfigSection(blueprint, apiKeys.keys.toList()),
                        const SizedBox(height: 32),
                        _buildStructureHeader(),
                        const SizedBox(height: 16),
                        _buildStructureList(blueprint),
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isAnalyzing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.white.withOpacity(0.4),
                  child: Center(
                    child: GlassCard(
                      width: 250,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
                          const SizedBox(height: 24),
                          Text(
                            _statusMsg,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text('AI sedang merancang skripsi Anda...', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isAnalyzing ? null : Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: GlassmorphismTheme.redGlowShadow,
          ),
          child: FloatingActionButton.extended(
            onPressed: _generateWithAI,
            backgroundColor: GlassmorphismTheme.primaryRed,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            label: Text('RANCANG DENGAN AI', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ResearchBlueprintState blueprint) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Research Architect',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GlassmorphismTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Rancang struktur penelitian Anda',
                  style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: GlassmorphismTheme.softShadow,
              ),
              child: IconButton(
                onPressed: _pickGuideline,
                icon: Icon(
                  Icons.picture_as_pdf_rounded, 
                  color: blueprint.guidelinePath != null ? Colors.green : GlassmorphismTheme.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(ResearchBlueprintState blueprint) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      margin: EdgeInsets.zero,
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Dasar',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: GlassmorphismTheme.primaryRed),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _judulController,
            maxLines: 3,
            onChanged: (v) => ref.read(researchBlueprintProvider.notifier).updateJudul(v),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Judul Penelitian',
              labelStyle: TextStyle(color: GlassmorphismTheme.textSecondary),
              hintText: 'Masukkan judul lengkap penelitian...',
              hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lokasiController,
            onChanged: (v) => ref.read(researchBlueprintProvider.notifier).updateLokasi(v),
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Lokasi / Objek Penelitian',
              labelStyle: TextStyle(color: GlassmorphismTheme.textSecondary),
              hintText: 'Contoh: PT. Sumber Makmur',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiConfigSection(ResearchBlueprintState blueprint, List<String> providers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'AI Engine',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: GlassmorphismTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: providers.map((p) {
              final isSelected = blueprint.selectedProvider == p;
              return GestureDetector(
                onTap: () {
                  ref.read(researchBlueprintProvider.notifier).updateAIConfig(provider: p, model: null);
                  _fetchModels();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected ? GlassmorphismTheme.redGlowShadow : GlassmorphismTheme.softShadow,
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStructureHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Struktur Bab',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: GlassmorphismTheme.textPrimary),
          ),
        ),
        IconButton(
          onPressed: () => ref.read(researchBlueprintProvider.notifier).addChapter(),
          icon: const Icon(Icons.add_circle_rounded, color: GlassmorphismTheme.primaryRed),
        ),
      ],
    );
  }

  Widget _buildStructureList(ResearchBlueprintState blueprint) {
    if (blueprint.structure.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.architecture_rounded, size: 64, color: Colors.black.withOpacity(0.05)),
              const SizedBox(height: 16),
              const Text('Klik Generate AI untuk membuat draf bab.', style: TextStyle(color: Colors.black38)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: blueprint.structure.map<Widget>((chapter) => _ChapterTile(chapter: chapter)).toList(),
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

class _ChapterTile extends ConsumerWidget {
  final ChapterBlueprint chapter;
  const _ChapterTile({required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          iconColor: GlassmorphismTheme.primaryRed,
          collapsedIconColor: GlassmorphismTheme.textSecondary,
          title: Text(
            chapter.babLabel, 
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: GlassmorphismTheme.primaryRed, fontSize: 14),
          ),
          subtitle: Text(
            chapter.title.isEmpty ? 'Tap untuk isi judul bab' : chapter.title, 
            style: GoogleFonts.inter(fontSize: 13, color: GlassmorphismTheme.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => ref.read(researchBlueprintProvider.notifier).updateChapter(chapter.id, title: v),
                    decoration: InputDecoration(
                      labelText: 'Judul Bab Lengkap',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    controller: TextEditingController(text: chapter.title)..selection = TextSelection.collapsed(offset: chapter.title.length),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sub-Bab (${chapter.subChapters.length})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                      IconButton(
                        onPressed: () => _editSubChapters(context, ref),
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (chapter.subChapters.isEmpty)
                    const Text('Belum ada sub-bab.', style: TextStyle(fontSize: 12, color: Colors.black26))
                  else
                    ...chapter.subChapters.map((sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 6, color: GlassmorphismTheme.primaryRed),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(sub, style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, height: 1.4))),
                        ],
                      ),
                    )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editSubChapters(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: chapter.subChapters.join('\n'));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Edit Sub-Bab ${chapter.babLabel}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: 'Masukkan satu sub-bab per baris...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final list = controller.text.split('\n').where((s) => s.trim().isNotEmpty).toList();
              ref.read(researchBlueprintProvider.notifier).updateChapter(chapter.id, subChapters: list);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: GlassmorphismTheme.primaryRed, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

