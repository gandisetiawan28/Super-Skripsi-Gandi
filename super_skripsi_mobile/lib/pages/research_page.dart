import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/documents_provider.dart';
import '../models/document_model.dart';
import '../providers/rag_service_provider.dart';
import '../providers/research_process_provider.dart';
import '../providers/api_keys_provider.dart';
import '../providers/latihan_provider.dart';
import 'pdf_viewer_page.dart';

class ResearchPage extends ConsumerStatefulWidget {
  const ResearchPage({super.key});

  @override
  ConsumerState<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends ConsumerState<ResearchPage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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
    _searchController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    ref.read(researchProcessProvider.notifier).addFiles(result.files);
    _showProcessingSheet();
  }

  void _showProcessingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProcessingBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final indexedIds = ref.watch(indexedDocsProvider).value ?? [];

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
                    bottom: -100 + (50 * _blobController.value),
                    right: -100 + (30 * _blobController.value),
                    child: _buildBlob(400, Colors.indigo.withOpacity(0.06)),
                  ),
                  Positioned(
                    top: 100 - (20 * _blobController.value),
                    left: -80 + (40 * _blobController.value),
                    child: _buildBlob(300, GlassmorphismTheme.primaryRed.withOpacity(0.05)),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: docsAsync.when(
                    data: (docs) {
                      final filteredDocs = docs.where((doc) {
                        final q = _searchQuery.toLowerCase();
                        return doc.title.toLowerCase().contains(q) ||
                               doc.authors.any((a) => a.toLowerCase().contains(q));
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final isIndexed = indexedIds.contains(doc.id);
                          return _buildDocumentCard(doc, isIndexed);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: GlassmorphismTheme.primaryRed)),
                    error: (e, s) => Center(child: Text('Gagal memuat dokumen: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: GlassmorphismTheme.redGlowShadow,
          ),
          child: FloatingActionButton(
            onPressed: _pickFiles,
            elevation: 0,
            backgroundColor: GlassmorphismTheme.primaryRed,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Research Hub',
                style: GoogleFonts.outfit(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: GlassmorphismTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Koleksi Referensi Ilmiah Anda',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: GlassmorphismTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: GlassmorphismTheme.softShadow,
            ),
            child: IconButton(
              onPressed: () => _showSettingsSheet(),
              icon: const Icon(Icons.tune_rounded, color: GlassmorphismTheme.textPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: 20,
        backgroundColor: Colors.white.withOpacity(0.6),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: GoogleFonts.inter(color: GlassmorphismTheme.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Cari judul atau penulis...',
            hintStyle: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: GlassmorphismTheme.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.black45),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.library_books_rounded, size: 80, color: Colors.black.withOpacity(0.05)),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada dokumen.',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: GlassmorphismTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _pickFiles,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: GlassmorphismTheme.primaryRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: GlassmorphismTheme.primaryRed.withOpacity(0.2)),
              ),
            ),
            child: const Text('Upload PDF Sekarang'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc, bool isIndexed) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: InkWell(
        onTap: () => _showDocDetails(doc, isIndexed),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GlassmorphismTheme.primaryRed.withOpacity(0.15),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: GlassmorphismTheme.primaryRed, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: GlassmorphismTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${doc.authors.isNotEmpty ? doc.authors.first : "Unknown"} • ${doc.year ?? "n.d."}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: GlassmorphismTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isIndexed)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.amber, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  void _showDocDetails(DocumentModel doc, bool isIndexed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DocDetailsSheet(doc: doc, isIndexed: isIndexed),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ResearchSettingsSheet(),
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

class _ProcessingBottomSheet extends ConsumerWidget {
  const _ProcessingBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processState = ref.watch(researchProcessProvider);
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14),
                width: 48, height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Proses Dokumen',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
                    ),
                    if (processState.isProcessing)
                      TextButton.icon(
                        onPressed: () => ref.read(researchProcessProvider.notifier).requestStop(),
                        icon: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 18),
                        label: const Text('Berhenti', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      )
                    else
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: processState.pendingFiles.isEmpty && !processState.isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('Antrean selesai.', style: TextStyle(color: Colors.black38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: processState.pendingFiles.length,
                      itemBuilder: (context, index) {
                        final item = processState.pendingFiles[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withOpacity(0.03)),
                          ),
                          child: ListTile(
                            leading: item.isProcessingAi 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassmorphismTheme.primaryRed))
                              : Icon(Icons.description_rounded, color: Colors.indigo.withOpacity(0.4)),
                            title: Text(item.file.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              item.errorMessage ?? (item.isProcessingAi ? 'AI sedang menganalisis...' : 'Menunggu antrean...'),
                              style: TextStyle(fontSize: 11, color: item.errorMessage != null ? Colors.red : Colors.black45),
                            ),
                          ),
                        );
                      },
                    ),
              ),
              if (processState.pendingFiles.isNotEmpty && !processState.isProcessing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: GlassmorphismTheme.redGlowShadow,
                    ),
                    child: ElevatedButton(
                      onPressed: () => ref.read(researchProcessProvider.notifier).processAllPending(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassmorphismTheme.primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        'MULAI PROSES AI',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocDetailsSheet extends ConsumerWidget {
  final DocumentModel doc;
  final bool isIndexed;
  const _DocDetailsSheet({required this.doc, required this.isIndexed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          doc.authors.join(', '),
                          style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (isIndexed)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.psychology_rounded, color: Colors.amber, size: 28),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              _buildActionBtn(
                label: isIndexed ? 'Update Index Brain' : 'Index ke Semantic Brain',
                icon: Icons.psychology_rounded,
                color: Colors.amber.shade800,
                onTap: () {
                  Navigator.pop(context);
                  _startIndexing(context, ref);
                },
              ),
              const SizedBox(height: 14),
              _buildActionBtn(
                label: 'Lihat Dokumen PDF',
                icon: Icons.menu_book_rounded,
                color: Colors.indigo.shade600,
                onTap: () {
                  if (doc.filePath != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfViewerPage(
                          filePath: doc.filePath!,
                          title: doc.title,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 14),
              _buildActionBtn(
                label: 'Hapus dari Koleksi',
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade600,
                onTap: () {
                  ref.read(documentsProvider.notifier).deleteDocument(doc.id, doc.filePath);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _startIndexing(BuildContext context, WidgetRef ref) async {
    if (doc.filePath == null) return;
    final aiSettings = ref.read(aiExtractionSettingsProvider);
    
    ref.read(ragStateProvider.notifier).indexDocument(
      filePath: doc.filePath!,
      docId: doc.id,
      title: doc.title,
      authors: doc.authors,
      provider: aiSettings.provider,
      model: aiSettings.model,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memulai indexing ke semantic brain...'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildActionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: Colors.white),
        label: Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class _ResearchSettingsSheet extends ConsumerWidget {
  const _ResearchSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiExtractionSettingsProvider);
    final apiKeys = ref.watch(apiKeysProvider);
    final modelsAsync = ref.watch(latihanModelsProvider);

    List<String> availableProviders = apiKeys.keys.toList();
    if (!availableProviders.contains('Google Gemini')) {
      availableProviders.add('Google Gemini');
    }
    availableProviders.sort();

    // Auto-select model logic
    ref.listen<AsyncValue<List<String>>>(latihanModelsProvider, (previous, next) {
      if (next is AsyncData<List<String>> && next.value.isNotEmpty) {
        final currentModel = ref.read(aiExtractionSettingsProvider).model;
        if (currentModel == null || !next.value.contains(currentModel)) {
          final notifier = ref.read(aiExtractionSettingsProvider.notifier);
          notifier.state = AiExtractionSettings(provider: settings.provider, model: next.value.first);
        }
      }
    });

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI Extraction Settings',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih provider untuk ekstraksi metadata & RAG',
                style: GoogleFonts.inter(fontSize: 13, color: GlassmorphismTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              
              // Provider Dropdown
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
                items: availableProviders.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                onChanged: (val) {
                  ref.read(aiExtractionSettingsProvider.notifier).state = AiExtractionSettings(provider: val, model: null);
                },
              ),
              
              const SizedBox(height: 16),
              
              // Model Dropdown
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
                  onChanged: (val) {
                    ref.read(aiExtractionSettingsProvider.notifier).state = AiExtractionSettings(provider: settings.provider, model: val);
                  },
                ),
                loading: () => const Center(child: LinearProgressIndicator(color: GlassmorphismTheme.primaryRed)),
                error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 11)),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassmorphismTheme.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text('Simpan Pengaturan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
