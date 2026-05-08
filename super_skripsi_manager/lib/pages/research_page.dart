import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/log_terminal.dart';
import '../providers/documents_provider.dart';
import '../models/document_model.dart';
import '../services/api_key_service.dart';
import '../providers/rag_service_provider.dart';
import '../providers/api_keys_provider.dart';
import '../services/model_fetch_service.dart';
import '../services/ai_extraction_service.dart';
import '../providers/research_process_provider.dart';
import '../services/ris_generator_service.dart';
import '../services/pdf_service.dart';
import '../providers/onboarding_provider.dart';
import '../providers/research_blueprint_provider.dart';
import '../prompts/rag_explorer_prompt.dart';

final apiKeysAvailableProvider = FutureProvider<Map<String, bool>>((ref) async {
  final email = ref.read(onboardingProvider).googleEmail;
  final service = ApiKeyService(email);
  final keys = await service.getAllKeysMap();
  return {
    'Google Gemini': (keys['Google Gemini'] ?? []).isNotEmpty,
    'OpenAI': (keys['OpenAI'] ?? []).isNotEmpty,
    'Groq': (keys['Groq'] ?? []).isNotEmpty,
    'Cerebras': (keys['Cerebras'] ?? []).isNotEmpty,
    'Localhost': (keys['Localhost'] ?? []).isNotEmpty,
  };
});

final dynamicModelsProvider = FutureProvider.family<List<String>, String>((ref, provider) async {
  if (provider.isEmpty) return [];
  final email = ref.read(onboardingProvider).googleEmail;
  final fetchService = ModelFetchService(ApiKeyService(email));
  return await fetchService.fetchModels(provider);
});

class ResearchPage extends ConsumerStatefulWidget {
  const ResearchPage({super.key});

  @override
  ConsumerState<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends ConsumerState<ResearchPage> {
  // Local state for UI only, processing state moved to researchProcessProvider
  String? _searchQuery;
  final Set<String> _selectedVariables = {};
  int? _startYear;
  int? _endYear;
  bool _showFilters = false;
  String? _libraryDirPath;
  bool _isSearchHovered = false;
  final Set<String> _selectedSubBabs = {}; // Set to track multi-selected sub-chapters
  String? _selectedFilterBab; // Track which Bab is currently active for filtering


  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _initLibraryPath();
  }

  Future<void> _initLibraryPath() async {
    final appDir = await getApplicationSupportDirectory();
    if (mounted) {
      setState(() {
        _libraryDirPath = '${appDir.path}${Platform.pathSeparator}library';
      });
    }
  }

  @override
  void dispose() {

    _searchController.dispose();
    super.dispose();
  }

  File? _resolveFile(DocumentModel doc) {
    if (doc.filePath != null) {
      final file = File(doc.filePath!);
      if (file.existsSync()) return file;
    }
    if (_libraryDirPath != null) {
      final fallback = File('$_libraryDirPath${Platform.pathSeparator}${doc.renamedFileName}');
      if (fallback.existsSync()) return fallback;
    }
    return null;
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    ref.read(researchProcessProvider.notifier).addFiles(result.files);
  }

  Future<void> _reprocessDocument(DocumentModel doc) async {
    final processNotifier = ref.read(researchProcessProvider.notifier);
    processNotifier.clearLogs();
    processNotifier.setProcessing(true);
    processNotifier.resetStopRequest();
    processNotifier.addLog('Memulai reproses AI untuk ${doc.title}...');
    
    final notifier = ref.read(documentsProvider.notifier);
    final aiSettings = ref.read(aiExtractionSettingsProvider);

    notifier.onLogMessage = (msg) => processNotifier.addLog(msg);

    try {
      await notifier.reprocessDocument(
        doc,
        providerOverride: aiSettings.provider,
        modelOverride: aiSettings.model,
        shouldStop: () => ref.read(researchProcessProvider).stopRequested,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumen berhasil di-reproses!')),
        );
      }
    } catch (e) {
      processNotifier.addLog('❌ Gagal mereproses: $e');
    } finally {
      notifier.onLogMessage = null;
      processNotifier.setProcessing(false);
    }
  }

  Future<void> _showEditDocDialog(DocumentModel doc) async {
    final titleController = TextEditingController(text: doc.title);
    final authorsController = TextEditingController(text: doc.authors.join(", "));
    final yearController = TextEditingController(text: doc.year ?? '');
    final journalController = TextEditingController(text: doc.journalName ?? '');
    final volumeController = TextEditingController(text: doc.volume ?? '');
    final issueController = TextEditingController(text: doc.issue ?? '');
    final pagesController = TextEditingController(text: doc.pages ?? '');
    final categoryController = TextEditingController(text: doc.category ?? '');
    final translatedTitleController = TextEditingController(text: doc.translatedTitle ?? '');
    final translatedCategoryController = TextEditingController(text: doc.translatedCategory ?? '');
    final publisherController = TextEditingController(text: doc.publisher ?? '');
    final isbnController = TextEditingController(text: doc.isbn ?? '');
    final placeController = TextEditingController(text: doc.placeOfPublication ?? '');

    bool isTranslating = false;

    final result = await showGlassDialog<bool>(
      context: context,
      title: 'Edit Bibliografi Dokumen',
      content: StatefulBuilder(
        builder: (context, setStateDialog) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlassField(titleController, 'Judul Dokumen', Icons.title, maxLines: null),
              _buildGlassField(authorsController, 'Penulis (pisahkan dengan koma)', Icons.person_outline, maxLines: null),
              Row(
                children: [
                  Expanded(child: _buildGlassField(yearController, 'Tahun', Icons.calendar_today_outlined)),
                  const SizedBox(width: 12),
                  if (doc.documentType == 'BOOK' || doc.documentType == 'THES')
                    Expanded(child: _buildGlassField(publisherController, 'Penerbit / Universitas', Icons.business_rounded))
                  else
                    Expanded(child: _buildGlassField(journalController, 'Nama Jurnal', Icons.book_outlined)),
                ],
              ),
              if (doc.documentType == 'BOOK' || doc.documentType == 'THES')
                Row(
                  children: [
                    Expanded(child: _buildGlassField(isbnController, 'ISBN', Icons.qr_code_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGlassField(placeController, 'Kota Terbit', Icons.location_city_rounded)),
                  ],
                ),
              if (doc.documentType == 'JOUR' || doc.documentType == 'CONF' || doc.documentType == null)
                Row(
                  children: [
                    Expanded(child: _buildGlassField(volumeController, 'Volume', Icons.numbers_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGlassField(issueController, 'Issue', Icons.tag_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGlassField(pagesController, 'Halaman', Icons.pages_rounded)),
                  ],
                ),
              _buildGlassField(categoryController, 'Variabel Penelitian (pisahkan dengan koma)', Icons.label_important_outline_rounded, maxLines: null),
              
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  const Text('Terjemahan / Alias Bilingual', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: isTranslating ? null : () async {
                      setStateDialog(() => isTranslating = true);
                      try {
                        final email = ref.read(onboardingProvider).googleEmail;
                        final extractor = AiExtractionService(ApiKeyService(email));
                        final settings = ref.read(aiExtractionSettingsProvider);
                        final prompt = 'Terjemahkan data berikut ke bahasa Inggris (jika bahasa Indonesia) atau Indonesia (jika Inggris). Berikan output JSON murni dengan key "translated_title" dan "translated_category". Data: Judul="${titleController.text}", Variabel="${categoryController.text}"';
                        final res = await extractor.extractCustom(
                          systemPrompt: 'You are a translation assistant. Respond only in valid JSON.',
                          userText: prompt,
                          provider: settings.provider ?? 'Google Gemini',
                          model: settings.model,
                        );
                        final json = jsonDecode(res);
                        setStateDialog(() {
                          if (json['translated_title'] != null) translatedTitleController.text = json['translated_title'];
                          if (json['translated_category'] != null) translatedCategoryController.text = json['translated_category'];
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal translate otomatis: $e')));
                      } finally {
                        setStateDialog(() => isTranslating = false);
                      }
                    },
                    icon: isTranslating 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 14, color: GlassmorphismTheme.primaryRed),
                    label: Text(isTranslating ? 'Menerjemahkan...' : 'Auto-Translate AI', style: const TextStyle(fontSize: 11, color: GlassmorphismTheme.primaryRed)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildGlassField(translatedTitleController, 'Judul Terjemahan', Icons.g_translate_rounded, maxLines: null),
              _buildGlassField(translatedCategoryController, 'Variabel Terjemahan', Icons.translate_rounded, maxLines: null),
            ],
          );
        }
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Simpan Perubahan'),
        ),
      ],
    );

    if (result == true) {
      try {
        await ref.read(documentsProvider.notifier).updateDocumentMetadata(doc, {
          'title': titleController.text.trim(),
          'authors': authorsController.text, 
          'year': yearController.text.trim(),
          'journal_name': journalController.text.trim(),
          'volume': volumeController.text.trim(),
          'issue': issueController.text.trim(),
          'pages': pagesController.text.trim(),
          'category': categoryController.text.trim(),
          'translated_title': translatedTitleController.text.trim(),
          'translated_category': translatedCategoryController.text.trim(),
          'publisher': publisherController.text.trim(),
          'isbn': isbnController.text.trim(),
          'place_of_publication': placeController.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bibliografi berhasil diperbarui.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e')));
        }
      }
    }
  }

  Widget _buildGlassField(TextEditingController controller, String label, IconData icon, {int? maxLines = 1, bool showLabel = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(label, style: const TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 13, color: GlassmorphismTheme.textPrimary),
            decoration: InputDecoration(
              hintText: !showLabel ? label : null,
              hintStyle: const TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 12),
              prefixIcon: Icon(icon, size: 18, color: GlassmorphismTheme.textSecondary),
              filled: true,
              fillColor: Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  /// Index dokumen ke Python RAG service (dipanggil di background setelah proses AI berhasil)
  Future<void> _indexToRag(String filePath) async {
    final ragState = ref.read(ragStateProvider);
    if (!ragState.isActive) return; // Skip jika RAG tidak aktif

    // Cari dokumen di database berdasarkan filePath
    final docs = ref.read(documentsProvider).value ?? [];
    DocumentModel? doc;
    try {
      doc = docs.firstWhere(
        (d) => d.filePath == filePath || (d.renamedFileName.isNotEmpty && filePath.endsWith(d.renamedFileName)),
      );
    } catch (_) {
      // Dokumen belum ada di DB (proses AI mungkin belum selesai) — coba lagi
      await Future.delayed(const Duration(seconds: 2));
      final updatedDocs = ref.read(documentsProvider).value ?? [];
      try {
        doc = updatedDocs.firstWhere(
          (d) => d.filePath == filePath || (d.renamedFileName.isNotEmpty && filePath.endsWith(d.renamedFileName)),
        );
      } catch (_) {
        return; // Tidak ketemu, skip
      }
    }

    if (doc == null) return;

    final processNotifier = ref.read(researchProcessProvider.notifier);
    
    // Aktifkan status processing agar tombol STOP muncul di log
    processNotifier.setProcessing(true);
    processNotifier.resetStopRequest();
    processNotifier.addLog('📤 Indexing ke semantic RAG...');

    // Pengecekan awal jika user sudah menekan stop
    if (ref.read(researchProcessProvider).stopRequested) {
      processNotifier.addLog('⏹️ Indexing dibatalkan oleh user.');
      processNotifier.setProcessing(false);
      return;
    }

    // Ambil SEMUA kunci API yang tersedia untuk provider ini (untuk rotasi)
    final aiSettings = ref.read(aiExtractionSettingsProvider);
    final selectedProvider = aiSettings.provider ?? 'Google Gemini';
    
    final allKeys = ref.read(apiKeysProvider);
    final providerKeys = allKeys[selectedProvider] ?? [];
    
    // Gabungkan semua key dengan koma untuk dikirim ke Python (Rotation Support)
    final apiKeyString = providerKeys.map((k) => k['key']).whereType<String>().join(',');
    final apiKey = apiKeyString.isNotEmpty ? apiKeyString : (selectedProvider == 'Localhost' ? 'http://localhost:3000/' : null);

    if (apiKey == null || apiKey.isEmpty) {
      processNotifier.addLog('❌ Indexing Gagal: API Key untuk $selectedProvider belum diatur.');
      processNotifier.addLog('💡 Silakan atur API Key di Settings terlebih dahulu.');
      processNotifier.setProcessing(false);
      return;
    }

    processNotifier.addLog('🤖 AI sedang membedah teori & sitasi (MANDATORY)...');
    processNotifier.addLog('⏳ Mohon tunggu, proses ini memakan waktu +/- 30 detik...');

    try {
      final error = await ref.read(ragStateProvider.notifier).indexDocument(
        filePath: filePath,
        docId: doc.id,
        title: doc.title,
        authors: doc.authors,
        year: doc.year?.toString(),
        journalName: doc.journalName,
        apiKey: apiKey,
        provider: selectedProvider,
        model: aiSettings.model ?? 'gemini-2.5-flash',
        judulSkripsi: ref.read(researchBlueprintProvider).judul,
        lokasiPenelitian: ref.read(researchBlueprintProvider).lokasi,
        kerangkaSkripsi: ref.read(researchBlueprintProvider).kerangkaAsText,
        systemPrompt: RagExplorerPrompt.build(
          judul: ref.read(researchBlueprintProvider).judul,
          lokasi: ref.read(researchBlueprintProvider).lokasi,
          selectedBab: _selectedFilterBab,
          selectedSubBabs: _selectedSubBabs.toList(),
          docMeta: {
            'title': doc.title,
            'authors': doc.authors.join(', '),
            'year': doc.year?.toString() ?? '',
            'journal': doc.journalName ?? '',
          },
        ),
      );
      
      // Cek apakah user menekan stop saat proses sedang berjalan
      if (ref.read(researchProcessProvider).stopRequested) {
        processNotifier.addLog('⏹️ Sinyal pembatalan dikirim ke Python & AI Bridge.');
      }

      // Pengecekan jika terjadi error atau stop
      if (ref.read(researchProcessProvider).stopRequested || error != null) {
        // Otomatis kirim sinyal stop ke bridge jika gagal/stop
        await ref.read(ragStateProvider.notifier).abortIndexing();
        
        if (ref.read(researchProcessProvider).stopRequested) {
          processNotifier.addLog('⏹️ Sinyal pembatalan dikirim ke Python & AI Bridge.');
        } else {
          processNotifier.addLog('🧹 Error terdeteksi: Otomatis membersihkan antrean AI Bridge...');
        }
      }

      if (ref.read(researchProcessProvider).stopRequested) {
         processNotifier.addLog('⏹️ Proses RAG dihentikan di tengah jalan.');
      } else if (error == null) {
        processNotifier.addLog('🧠 Berhasil diindex ke ChromaDB (semantic search aktif)');
      } else {
        processNotifier.addLog('⚠️ RAG index gagal: $error');
        if (!error.contains('Timeout')) {
          processNotifier.addLog('Akan tetap tersedia via keyword search (TF-IDF).');
        }
      }
    } catch (e) {
      // Otomatis bersihkan jika fatal error
      await ref.read(ragStateProvider.notifier).abortIndexing();
      processNotifier.addLog('❌ Fatal error saat RAG: $e');
      processNotifier.addLog('🧹 Otomatis membersihkan antrean AI Bridge...');
    } finally {
      processNotifier.setProcessing(false);
    }
    // Refresh daftar indexed docs agar badge muncul
    ref.invalidate(indexedDocsProvider);
  }


  Future<void> _exportRis(String risData, String fileName) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export RIS',
      fileName: fileName.replaceAll('.pdf', '.ris'),
      type: FileType.custom,
      allowedExtensions: ['ris'],
    );
    if (savePath != null) {
      await File(savePath).writeAsString(risData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File RIS berhasil disimpan!')),
        );
      }
    }
  }

  Future<void> _downloadPdf(DocumentModel doc) async {
    final file = _resolveFile(doc);
    if (file == null || !file.existsSync()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File PDF tidak ditemukan di library.')));
      return;
    }

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Download PDF',
      fileName: doc.renamedFileName.isNotEmpty ? doc.renamedFileName : doc.originalFileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (savePath != null) {
      try {
        // Step: Inject metadata before saving to final location
        final pdfService = PdfService();
        await pdfService.updateMetadata(
          file.path, 
          savePath, 
          {
            'title': doc.title,
            'author': doc.authors.join(', '),
            'subject': doc.documentType ?? 'Research Document',
            'keywords': doc.category ?? '',
          }
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('PDF Berhasil diunduh & Metadata diperbarui!')),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        // Fallback to normal copy if injection fails (e.g. py not found or file locked)
        await file.copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF diunduh tanpa update metadata: $e')),
          );
        }
      }
    }
  }

  // Fungsi _getModelsForProvider dan _getDefaultModel dihapus karena sekarang dynamic

  Future<void> _bulkDownload(List<DocumentModel> docs) async {
    final saveDirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pilih Folder Tujuan Bulk Export');
    if (saveDirPath == null) return;

    try {
      final batchRis = ref.read(documentsProvider.notifier).risService.generateBatchRis(docs);
      await File('$saveDirPath${Platform.pathSeparator}All_Documents.ris').writeAsString(batchRis);

      int count = 0;
      for (final doc in docs) {
        final f = _resolveFile(doc);
        if (f != null && await f.exists()) {
          await f.copy('$saveDirPath${Platform.pathSeparator}${doc.renamedFileName}');
          count++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil diexport $count PDF & RIS ke $saveDirPath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
      }
    }
  }

  Future<void> _showManualRAGDialog(DocumentModel doc) async {
    final verbatimController = TextEditingController();
    final authorController = TextEditingController(text: doc.authors.join(", "));
    final yearController = TextEditingController(text: doc.year?.toString() ?? "");
    
    final authorAsliController = TextEditingController();
    final yearAsliController = TextEditingController();
    final authorAsli2Controller = TextEditingController();
    final yearAsli2Controller = TextEditingController();
    
    final pageController = TextEditingController();
    final subBabController = TextEditingController();
    String citationType = 'Primer';
    bool isSaving = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ManualRAG',
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return GlassDialog(
              title: 'Input Teori Manual RAG',
              maxWidth: 600,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('File: ${doc.title}', 
                    style: TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 11),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 16),
                  
                  const Text('Jenis Sitasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: citationType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13),
                      items: ['Primer', 'Sekunder', 'Sekunder 2']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: GlassmorphismTheme.textPrimary))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            citationType = val;
                            if (val == 'Primer') {
                              authorController.text = doc.authors.join(", ");
                              yearController.text = doc.year?.toString() ?? "";
                            }
                          });
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (citationType == 'Primer') ...[
                    _buildGlassField(authorController, 'Penulis Jurnal', Icons.person_rounded),
                    _buildGlassField(yearController, 'Tahun', Icons.calendar_today_rounded),
                  ] else if (citationType == 'Sekunder') ...[
                    const Text('Sumber Asli (Ahli):', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGlassField(authorAsliController, 'Nama Ahli', Icons.person_search_rounded, showLabel: false)),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: _buildGlassField(yearAsliController, 'Tahun', Icons.calendar_today_rounded, showLabel: false)),
                      ],
                    ),
                    const Text('Dikutip dalam Jurnal:', style: TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    _buildGlassField(authorController, 'Penulis Jurnal', Icons.person_rounded, showLabel: false),
                  ] else if (citationType == 'Sekunder 2') ...[
                    const Text('Sumber Asli 1 (Ahli):', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGlassField(authorAsliController, 'Nama Ahli 1', Icons.person_rounded, showLabel: false)),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: _buildGlassField(yearAsliController, 'Tahun', Icons.calendar_today_rounded, showLabel: false)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Dikutip oleh Ahli 2:', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGlassField(authorAsli2Controller, 'Nama Ahli 2', Icons.person_rounded, showLabel: false)),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: _buildGlassField(yearAsli2Controller, 'Tahun', Icons.calendar_today_rounded, showLabel: false)),
                      ],
                    ),
                    const Text('Dikutip dalam Jurnal:', style: TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    _buildGlassField(authorController, 'Penulis Jurnal', Icons.person_rounded, showLabel: false),
                  ],

                  const Text('Kutipan Verbatim (Teks Asli):', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildGlassField(verbatimController, 'Copy-paste teks asli dari PDF di sini...', Icons.format_quote_rounded, showLabel: false, maxLines: 4),

                  Row(
                    children: [
                      Expanded(child: _buildGlassField(pageController, 'Halaman', Icons.pages_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGlassField(subBabController, 'Sub-Bab / Variabel', Icons.topic_rounded)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text('Batal', style: TextStyle(color: GlassmorphismTheme.textSecondary))
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (verbatimController.text.isEmpty) return;
                    setDialogState(() => isSaving = true);
                    try {
                      String sitasiFinal = "";
                      final pAuthor = authorController.text;
                      final pYear = yearController.text;

                      if (citationType == 'Primer') {
                        sitasiFinal = '($pAuthor, $pYear)';
                      } else if (citationType == 'Sekunder') {
                        sitasiFinal = '(${authorAsliController.text}, ${yearAsliController.text}, dalam $pAuthor, $pYear)';
                      } else if (citationType == 'Sekunder 2') {
                        sitasiFinal = '(${authorAsliController.text}, ${yearAsliController.text}, dalam ${authorAsli2Controller.text}, ${yearAsli2Controller.text}, dikutip oleh $pAuthor, $pYear)';
                      }

                      final payload = {
                        "doc_id": doc.id,
                        "content": verbatimController.text,
                        "metadata": {
                          "sub_bab": subBabController.text.isEmpty ? "Manual" : subBabController.text,
                          "sitasi": sitasiFinal,
                          "halaman": pageController.text,
                          "jenis_sumber": citationType,
                          "source_title": doc.title,
                          "is_manual": "true"
                        }
                      };

                      final res = await http.post(
                        Uri.parse('http://localhost:28146/add_manual'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(payload),
                      );

                      if (res.statusCode == 200) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teori berhasil ditambahkan!')));
                          Navigator.pop(ctx);
                          ref.invalidate(indexedDocsProvider);
                        }
                      } else {
                        throw Exception(res.body);
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    } finally {
                      setDialogState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: GlassmorphismTheme.success),
                  child: isSaving 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Ke RAG'),
                ),
              ],
            );
          }
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }




  Widget _buildHeader(AsyncValue<List<DocumentModel>> docs) {
    final aiSettings = ref.watch(aiExtractionSettingsProvider);
    final availableKeys = ref.watch(apiKeysAvailableProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Research Hub',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: GlassmorphismTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload PDF → Otomatis diproses, diarsipkan, dan siap untuk RAG.',
                  style: GoogleFonts.inter(fontSize: 13, color: GlassmorphismTheme.textSecondary),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: DropdownButton<String?>(
                        value: aiSettings.provider,
                        hint: Text('Auto Intelligence', style: TextStyle(color: GlassmorphismTheme.textPrimary.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                        icon: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.psychology_rounded, color: GlassmorphismTheme.textPrimary.withOpacity(0.7), size: 20),
                        ),
                        dropdownColor: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        elevation: 8,
                        style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Auto Intelligence', style: TextStyle(color: GlassmorphismTheme.textPrimary.withOpacity(0.8)))),
                          if (availableKeys.value?['Google Gemini'] == true)
                            const DropdownMenuItem(value: 'Google Gemini', child: Text('Google Gemini')),
                          if (availableKeys.value?['OpenAI'] == true)
                            const DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
                          if (availableKeys.value?['Groq'] == true)
                            const DropdownMenuItem(value: 'Groq', child: Text('Groq')),
                          if (availableKeys.value?['Cerebras'] == true)
                            const DropdownMenuItem(value: 'Cerebras', child: Text('Cerebras')),
                          if (availableKeys.value?['Localhost'] == true)
                            const DropdownMenuItem(value: 'Localhost', child: Text('Localhost')),
                        ],
                        onChanged: (val) {
                          ref.read(aiExtractionSettingsProvider.notifier).state = 
                              AiExtractionSettings(provider: val, model: null);
                        },
                      ),
                    ),
                    if (aiSettings.provider != null) ...[
                      const SizedBox(width: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final modelsAsync = ref.watch(dynamicModelsProvider(aiSettings.provider!));
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: modelsAsync.when(
                              loading: () => const Row(
                                children: [
                                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                                  SizedBox(width: 8),
                                  Text('Memuat model...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                              error: (e, st) => Text('Error: ${e.toString().split('\n').first}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                              data: (models) {
                                if (models.isEmpty) {
                                  return Text('Tidak ada model', style: TextStyle(color: GlassmorphismTheme.textPrimary.withOpacity(0.5), fontSize: 13));
                                }
                                
                                // Jika belum ada model terpilih, atau model yang terpilih tidak ada di list, otomatis pilih yang pertama
                                String selectedModel = aiSettings.model ?? models.first;
                                if (!models.contains(selectedModel)) selectedModel = models.first;

                                // Gunakan post-frame callback untuk mengupdate state model jika belum tersimpan
                                if (aiSettings.model != selectedModel) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    ref.read(aiExtractionSettingsProvider.notifier).state = 
                                        AiExtractionSettings(provider: aiSettings.provider, model: selectedModel);
                                  });
                                }
                                
                                return DropdownButton<String>(
                                  value: selectedModel,
                                  icon: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(Icons.arrow_drop_down_rounded, color: GlassmorphismTheme.textPrimary.withOpacity(0.7), size: 20),
                                  ),
                                  dropdownColor: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  elevation: 8,
                                  style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  underline: const SizedBox(),
                                  items: models.map((m) {
                                    return DropdownMenuItem(value: m, child: Text(m));
                                  }).toList(),
                                  onChanged: (val) {
                                    ref.read(aiExtractionSettingsProvider.notifier).state = 
                                        AiExtractionSettings(provider: aiSettings.provider, model: val);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                if (docs.value != null && docs.value!.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                    tooltip: 'Download Semua PDF & RIS',
                    icon: const Icon(Icons.download_for_offline_rounded, color: GlassmorphismTheme.success),
                    onPressed: () => _bulkDownload(docs.value!),
                  ),
                  IconButton(
                    tooltip: 'Kosongkan Perpustakaan',
                    icon: const Icon(Icons.delete_sweep_rounded, color: GlassmorphismTheme.error),
                    onPressed: () async {
                      final confirm = await showGlassDialog<bool>(
                        context: context,
                        title: 'Kosongkan Perpustakaan?',
                        content: const Text('Seluruh database dan file library akan dihapus secara permanen.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: GlassmorphismTheme.error),
                            child: const Text('Hapus Sekarang'),
                          ),
                        ],
                      );
                      if (confirm == true) ref.read(documentsProvider.notifier).clearLibrary();
                    },
                  ),
                ], // end children of Wrap
              ), // end Wrap
            ], // end if
            ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.add_to_photos_rounded, size: 18),
                  label: const Text('Pilih Dokumen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassmorphismTheme.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }



  void _showExtractedText(BuildContext context, String fileName, String text) {
    showGlassDialog(
      context: context,
      title: fileName,
      maxWidth: 800,
      content: Container(
        width: double.maxFinite,
        height: 400,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 13, height: 1.5, color: GlassmorphismTheme.textPrimary),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildPendingQueue() {
    final processState = ref.watch(researchProcessProvider);
    final processNotifier = ref.read(researchProcessProvider.notifier);
    
    if (processState.pendingFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              'Antrean Dokumen Baru (${processState.pendingFiles.length})',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
            ),
            const Spacer(),
            if (processState.isProcessing)
               ElevatedButton.icon(
                onPressed: processState.stopRequested ? null : () => processNotifier.requestStop(),
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: Text(processState.stopRequested ? 'Menghentikan...' : 'Stop Semua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: processState.pendingFiles.any((f) => f.extractedText != null) 
                    ? () => processNotifier.processAllPending()
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Proses Semua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.success,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear_all_rounded, color: GlassmorphismTheme.textSecondary),
              tooltip: 'Bersihkan Antrean',
              onPressed: processState.isProcessing ? null : () => processNotifier.clearAllPending(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...processState.pendingFiles.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _PendingFileCard(
            item: item,
            onShowExtracted: () => _showExtractedText(context, item.file.name, item.extractedText!),
            onProcess: () => processNotifier.processAllPending(),
            onRemove: () => processNotifier.removeFile(item.file.path!),
            delay: Duration(milliseconds: index * 100),
          );
        }).toList(),
        const Divider(height: 40, color: Colors.white10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);
    final processState = ref.watch(researchProcessProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(docs),
          const SizedBox(height: 24),
          
          _buildPendingQueue(),
          

          const SizedBox(height: 24),
          _buildStructureFilterCard(),
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.library_books_rounded, color: GlassmorphismTheme.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Perpustakaan Internal',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(_showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded, size: 18),
                label: Text(_showFilters ? 'Tutup Filter' : 'Filter Lanjutan'),
                style: TextButton.styleFrom(foregroundColor: GlassmorphismTheme.textPrimary),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 12),
            _buildAdvancedFilterPanel(docs.value ?? []),
          ],
          const SizedBox(height: 12),
          
          MouseRegion(
            onEnter: (_) => setState(() => _isSearchHovered = true),
            onExit: (_) => setState(() => _isSearchHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_isSearchHovered ? 1.0 : 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isSearchHovered 
                      ? GlassmorphismTheme.primaryRed.withOpacity(0.4) 
                      : GlassmorphismTheme.primaryRed.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isSearchHovered 
                        ? GlassmorphismTheme.primaryRed.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.04),
                    blurRadius: _isSearchHovered ? 16 : 12,
                    offset: _isSearchHovered ? const Offset(0, 6) : const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, 
                    color: _isSearchHovered ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.primaryRed.withOpacity(0.8), 
                    size: 20
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _isSearchHovered ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary,
                        fontWeight: _isSearchHovered ? FontWeight.w600 : FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari dalam perpustakaan (Judul, Author, Variabel)...', 
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: GoogleFonts.inter(
                          color: (_isSearchHovered ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary).withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery != null && _searchQuery!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: _isSearchHovered ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          if (processState.logs.isNotEmpty) 
            SizedBox(
              height: 180, 
              child: LogTerminal(
                logs: processState.logs,
                isProcessing: processState.isProcessing,
                onClear: () => ref.read(researchProcessProvider.notifier).clearLogs(),
                onStop: () {
                  ref.read(researchProcessProvider.notifier).requestStop();
                  // Sinyal ke Python & Bridge
                  ref.read(ragStateProvider.notifier).abortIndexing();
                },
              ),
            ),
          const SizedBox(height: 20),
          
          docs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (documents) {
              final filtered = documents.where((d) {
                final query = _searchQuery?.toLowerCase() ?? '';
                final matchesSearch = query.isEmpty || 
                                     d.title.toLowerCase().contains(query) || 
                                     (d.translatedTitle?.toLowerCase().contains(query) ?? false) ||
                                     d.authors.any((a) => a.toLowerCase().contains(query)) ||
                                     (d.category?.toLowerCase().contains(query) ?? false) ||
                                     (d.translatedCategory?.toLowerCase().contains(query) ?? false);
                
                bool matchesVariable = _selectedVariables.isEmpty;
                if (!matchesVariable) {
                  final List<String> allVars = [];
                  if (d.category != null) allVars.addAll(d.category!.split(',').map((e) => e.trim().toLowerCase()));
                  if (d.translatedCategory != null) allVars.addAll(d.translatedCategory!.split(',').map((e) => e.trim().toLowerCase()));
                  
                  matchesVariable = _selectedVariables.any((v) => allVars.contains(v.toLowerCase()));
                }

                bool matchesYear = true;
                if (d.year != null) {
                  final y = int.tryParse(d.year!);
                  if (y != null) {
                    if (_startYear != null && y < _startYear!) matchesYear = false;
                    if (_endYear != null && y > _endYear!) matchesYear = false;
                  }
                }
                
                return matchesSearch && matchesVariable && matchesYear;
              }).toList();
              
              final indexedDocsAsync = ref.watch(indexedDocsProvider);
              final indexedIds = indexedDocsAsync.value ?? [];
              
              if (filtered.isEmpty && processState.pendingFiles.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Perpustakaan kosong.')));
              }
              
              return LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 1;
                  if (constraints.maxWidth > 1200) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth > 800) {
                    crossAxisCount = 2;
                  }
                  
                  return MasonryGridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildDocumentCard(filtered[index], indexedIds, index);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc, List<String> indexedIds, int index) {
    return _DocumentCardItem(
      doc: doc,
      isIndexed: indexedIds.contains(doc.id),
      onEdit: () => _showEditDocDialog(doc),
      onDelete: () => ref.read(documentsProvider.notifier).deleteDocument(doc.id, doc.filePath),
      onExtract: (file) => _indexToRag(file.path),
      onReprocess: () => _reprocessDocument(doc),
      onExportRis: (ris, name) => _exportRis(ris, name),
      onDownloadPdf: () => _downloadPdf(doc),
      onManualRAG: () => _showManualRAGDialog(doc),
      delay: Duration(milliseconds: index * 100),
    );
  }




  Widget _buildStructureFilterCard() {
    final blueprint = ref.watch(researchBlueprintProvider);
    if (blueprint.structure.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, size: 18, color: GlassmorphismTheme.primaryRed),
              const SizedBox(width: 10),
              Text('Filter Berdasarkan Struktur Skripsi',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: GlassmorphismTheme.textPrimary)),
              const Spacer(),
              if (_selectedFilterBab != null || _selectedSubBabs.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilterBab = null;
                      _selectedSubBabs.clear();
                    });
                  },
                  child: Text('Reset Filter', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.primaryRed)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row for BAB Selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Semua Bab',
                  isSelected: _selectedFilterBab == null,
                  onTap: () => setState(() {
                    _selectedFilterBab = null;
                    _selectedSubBabs.clear();
                  }),
                ),
                ...blueprint.structure.map((bab) => _buildFilterChip(
                  label: bab.babLabel,
                  isSelected: _selectedFilterBab == bab.babLabel,
                  onTap: () => setState(() {
                    _selectedFilterBab = bab.babLabel;
                    _selectedSubBabs.clear();
                  }),
                )),
              ],
            ),
          ),

          // Sub-Chapters (Multi-select)
          if (_selectedFilterBab != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Colors.white10),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Tombol Pilih Semua
                _buildSubChapterChip(
                  label: "Pilih Semua",
                  isSelected: _selectedSubBabs.length == blueprint.structure
                      .firstWhere((b) => b.babLabel == _selectedFilterBab)
                      .subChapters.length,
                  onTap: () {
                    final currentSubBabs = blueprint.structure
                        .firstWhere((b) => b.babLabel == _selectedFilterBab)
                        .subChapters;
                    setState(() {
                      if (_selectedSubBabs.length == currentSubBabs.length) {
                        _selectedSubBabs.clear();
                      } else {
                        _selectedSubBabs.addAll(currentSubBabs);
                      }
                    });
                  },
                ),
                ...blueprint.structure
                    .firstWhere((b) => b.babLabel == _selectedFilterBab)
                    .subChapters
                    .map((sub) {
                    final isSelected = _selectedSubBabs.contains(sub);
                    return _buildSubChapterChip(
                      label: sub,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedSubBabs.remove(sub);
                          } else {
                            _selectedSubBabs.add(sub);
                          }
                        });
                      },
                    );
                  }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : GlassmorphismTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubChapterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    // Determine level by indentation (space)
    final level = (label.length - label.trimLeft().length) ~/ 2;
    final cleanLabel = label.trim();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blueAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) 
              const Icon(Icons.check_rounded, size: 14, color: Colors.blueAccent),
            if (isSelected) const SizedBox(width: 6),
            Text(
              cleanLabel,
              style: GoogleFonts.inter(
                fontSize: 11 - (level * 0.5),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.blueAccent : GlassmorphismTheme.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilterPanel(List<DocumentModel> docs) {
    // Extract unique variables and years
    final Set<String> variables = {};
    final Set<int> years = {};
    for (var doc in docs) {
      if (doc.category != null && doc.category != 'Unknown' && doc.category!.isNotEmpty) {
        for (var p in doc.category!.split(',')) {
          final trimmed = p.trim();
          if (trimmed.isNotEmpty) variables.add(trimmed);
        }
      }
      if (doc.year != null) {
        final y = int.tryParse(doc.year!);
        if (y != null) years.add(y);
      }
    }

    final sortedVars = variables.toList()..sort();
    final sortedYears = years.toList()..sort();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rentang Tahun', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildYearDropdown('Dari', sortedYears, _startYear, (v) => setState(() => _startYear = v)),
              const SizedBox(width: 16),
              _buildYearDropdown('Sampai', sortedYears, _endYear, (v) => setState(() => _endYear = v)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _startYear = null;
                  _endYear = null;
                  _selectedVariables.clear();
                }),
                child: const Text('Reset Filter', style: TextStyle(color: GlassmorphismTheme.primaryRed, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Variabel Penelitian (Checkbox)', style: TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedVars.map((v) {
              final isSelected = _selectedVariables.contains(v);
              return InkWell(
                onTap: () => setState(() => isSelected ? _selectedVariables.remove(v) : _selectedVariables.add(v)),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, 
                           size: 16, color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(v, style: TextStyle(color: isSelected ? GlassmorphismTheme.textPrimary : GlassmorphismTheme.textSecondary, fontSize: 11)),
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

  Widget _buildYearDropdown(String label, List<int> years, int? selected, Function(int?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<int?>(
            value: selected,
            hint: const Text('Pilih', style: TextStyle(fontSize: 12)),
            underline: const SizedBox(),
            dropdownColor: Colors.white,
            style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua')),
              ...years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// PendingFileItem moved to research_process_provider.dart

class _PendingFileCard extends StatefulWidget {
  final PendingFileItem item;
  final VoidCallback onShowExtracted;
  final VoidCallback onProcess;
  final VoidCallback onRemove;
  final Duration delay;

  const _PendingFileCard({
    required this.item,
    required this.onShowExtracted,
    required this.onProcess,
    required this.onRemove,
    required this.delay,
  });

  @override
  State<_PendingFileCard> createState() => _PendingFileCardState();
}

class _PendingFileCardState extends State<_PendingFileCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_isHovered ? 0.95 : 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isHovered ? GlassmorphismTheme.primaryRed.withOpacity(0.3) : Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                  blurRadius: _isHovered ? 12 : 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: GlassmorphismTheme.primaryRed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.file.name,
                          style: const TextStyle(color: GlassmorphismTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (widget.item.isExtracting)
                          const Row(
                            children: [
                              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                              SizedBox(width: 6),
                              Text('Mengekstrak teks lokal...', style: TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 11)),
                            ],
                          )
                        else if (widget.item.errorMessage != null)
                          Text('Gagal: ${widget.item.errorMessage}', style: const TextStyle(color: GlassmorphismTheme.error, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                        else
                          Text('Teks berhasil diekstrak (${widget.item.extractedText?.length ?? 0} karakter)', style: const TextStyle(color: GlassmorphismTheme.success, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!widget.item.isExtracting && widget.item.extractedText != null)
                    TextButton.icon(
                      onPressed: widget.onShowExtracted,
                      icon: const Icon(Icons.visibility_rounded, size: 14),
                      label: const Text('Lihat Teks'),
                      style: TextButton.styleFrom(
                        foregroundColor: GlassmorphismTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (widget.item.isExtracting || widget.item.isProcessingAi || widget.item.extractedText == null) 
                        ? null 
                        : widget.onProcess,
                    icon: widget.item.isProcessingAi 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: const Text('Generate RIS & Rename'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366f1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GlassmorphismTheme.textSecondary, size: 18),
                    onPressed: widget.onRemove,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCardItem extends StatefulWidget {
  final DocumentModel doc;
  final bool isIndexed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(File) onExtract;
  final VoidCallback onReprocess;
  final Function(String, String) onExportRis;
  final VoidCallback onDownloadPdf;
  final VoidCallback onManualRAG;
  final Duration delay;

  const _DocumentCardItem({
    required this.doc,
    required this.isIndexed,
    required this.onEdit,
    required this.onDelete,
    required this.onExtract,
    required this.onReprocess,
    required this.onExportRis,
    required this.onDownloadPdf,
    required this.onManualRAG,
    this.delay = Duration.zero,
  });

  @override
  State<_DocumentCardItem> createState() => _DocumentCardItemState();
}

class _DocumentCardItemState extends State<_DocumentCardItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.delay == Duration.zero) {
      _entranceController.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _entranceController.forward();
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdfFile = widget.doc.filePath != null ? File(widget.doc.filePath!) : null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            transform: _isHovered 
                ? (Matrix4.identity()..scale(1.02)) 
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                      ? GlassmorphismTheme.primaryRed.withOpacity(0.15) 
                      : Colors.black.withOpacity(0.05),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: _isHovered 
                    ? GlassmorphismTheme.primaryRed.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon Section
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 40,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isHovered 
                                ? [GlassmorphismTheme.primaryRed, const Color(0xFFFF8E8E)]
                                : [GlassmorphismTheme.primaryRed.withOpacity(0.8), GlassmorphismTheme.primaryRedDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.doc.category != null && widget.doc.category != 'Unknown' && widget.doc.category!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: widget.doc.category!.split(',').map((cat) {
                                      final cleanCat = cat.trim();
                                      if (cleanCat.isEmpty) return const SizedBox.shrink();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          cleanCat.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: GlassmorphismTheme.primaryRed,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              // Info Publisher/Jurnal di atas Judul
                              if ((widget.doc.documentType == 'BOOK' || widget.doc.documentType == 'THES' 
                                    ? widget.doc.publisher 
                                    : widget.doc.journalName) != null && 
                                  (widget.doc.documentType == 'BOOK' || widget.doc.documentType == 'THES' 
                                    ? widget.doc.publisher 
                                    : widget.doc.journalName) != 'Unknown' && 
                                  (widget.doc.documentType == 'BOOK' || widget.doc.documentType == 'THES' 
                                    ? widget.doc.publisher 
                                    : widget.doc.journalName)!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    (widget.doc.documentType == 'BOOK' || widget.doc.documentType == 'THES' 
                                      ? widget.doc.publisher! 
                                      : widget.doc.journalName!).toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: GlassmorphismTheme.textSecondary.withOpacity(0.7),
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              InkWell(
                                onTap: widget.onManualRAG,
                                child: Text(
                                  widget.doc.title,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: GlassmorphismTheme.textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.doc.authors.join(", ")} • ${widget.doc.year ?? "N/A"}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: GlassmorphismTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (widget.isIndexed)
                                    _buildMiniBadge(
                                      label: 'Semantic Ready',
                                      icon: Icons.auto_awesome,
                                      color: Colors.green.shade600,
                                    ),
                                  if (widget.doc.risData != null)
                                    _buildMiniBadge(
                                      label: 'RIS Metadata',
                                      icon: Icons.description_outlined,
                                      color: Colors.blue.shade600,
                                    ),
                                  _buildMiniBadge(
                                    label: 'PDF',
                                    icon: Icons.file_present_rounded,
                                    color: GlassmorphismTheme.textSecondary,
                                  ),
                                  _buildMiniBadge(
                                    label: '${widget.doc.chunkCount} Teori',
                                    icon: Icons.psychology_alt_rounded,
                                    color: Colors.orange.shade700,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Edit/Delete
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, 
                                size: 18, 
                                color: _isHovered ? Colors.blue : Colors.blueAccent.withOpacity(0.6)),
                              onPressed: widget.onEdit,
                              tooltip: 'Edit Bibliografi',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_sweep_outlined, 
                                size: 18, 
                                color: _isHovered ? Colors.red.withOpacity(0.7) : Colors.black26),
                              onPressed: widget.onDelete,
                              tooltip: 'Hapus Dokumen',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isHovered ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildCardAction(
                          icon: Icons.psychology_rounded,
                          label: 'Ekstrak Teori (RAG)',
                          color: const Color(0xFF6366f1),
                          onTap: () => pdfFile != null ? widget.onExtract(pdfFile) : null,
                        ),
                        if (pdfFile != null)
                          _buildCardAction(
                            icon: Icons.visibility_rounded,
                            label: 'Buka',
                            color: GlassmorphismTheme.primaryRed,
                            onTap: () => launchUrl(Uri.file(pdfFile.path)),
                          ),
                        _buildCardAction(
                          icon: Icons.download_rounded,
                          label: 'RIS',
                          color: Colors.blueGrey,
                          onTap: () {
                          // Selalu regenerate RIS dari data live agar sesuai document_type terbaru
                          final freshRis = RisGeneratorService().generateRis(widget.doc);
                          widget.onExportRis(freshRis, widget.doc.renamedFileName);
                        },
                        ),
                        _buildCardAction(
                          icon: Icons.file_download_rounded,
                          label: 'PDF',
                          color: Colors.redAccent,
                          onTap: widget.onDownloadPdf,
                        ),
                        _buildCardAction(
                          icon: Icons.refresh_rounded,
                          label: 'AI',
                          color: Colors.teal,
                          onTap: widget.onReprocess,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final bool isDisabled = onTap == null;
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDisabled ? Colors.grey.withOpacity(0.2) : color.withOpacity(_isHovered ? 0.4 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isDisabled ? Colors.grey : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.grey : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


