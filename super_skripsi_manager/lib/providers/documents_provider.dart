import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/pdf_service.dart';
import '../services/hashing_service.dart';
import '../services/chunking_service.dart';
import '../services/vector_store_service.dart';
import '../services/ai_extraction_service.dart';
import '../services/api_key_service.dart';
import '../services/ris_generator_service.dart';
import '../services/sync_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'onboarding_provider.dart';

final vectorStoreProvider = Provider<VectorStoreService>((ref) {
  final email = ref.watch(onboardingProvider).googleEmail;
  return VectorStoreService(email);
});

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, AsyncValue<List<DocumentModel>>>((ref) {
  final vectorStore = ref.watch(vectorStoreProvider);
  final apiKeyService = ref.watch(_apiKeyServiceProvider);
  return DocumentsNotifier(ref, vectorStore, apiKeyService);
});

final aiExtractionSettingsProvider = StateProvider<AiExtractionSettings>((ref) {
  return AiExtractionSettings(provider: null, model: null); // null = Auto
});

class AiExtractionSettings {
  final String? provider;
  final String? model;
  const AiExtractionSettings({this.provider, this.model});
}

final _apiKeyServiceProvider = Provider<ApiKeyService>((ref) {
  final email = ref.watch(onboardingProvider).googleEmail;
  return ApiKeyService(email);
});

class DocumentsNotifier extends StateNotifier<AsyncValue<List<DocumentModel>>> {
  final Ref ref;
  final VectorStoreService _vectorStore;
  final ApiKeyService _apiKeyService;
  final PdfService _pdfService = PdfService();
  final HashingService _hashingService = HashingService();
  final RisGeneratorService risService = RisGeneratorService();

  // Processing status log
  final List<String> processLog = [];
  Function(String)? onLogMessage;

  DocumentsNotifier(this.ref, this._vectorStore, this._apiKeyService)
      : super(const AsyncValue.loading()) {
    _loadDocuments();
  }

  void _log(String msg) {
    processLog.add('[${DateTime.now().toIso8601String()}] $msg');
    onLogMessage?.call(msg);
  }

  Future<void> _loadDocuments() async {
    try {
      final rows = await _vectorStore.getAllDocuments();
      final docs = rows.map((r) => DocumentModel(
            id: r['id'] as String,
            originalFileName: r['original_filename'] as String,
            renamedFileName: r['renamed_filename'] as String,
            title: r['title'] as String,
            authors: List<String>.from(jsonDecode(r['authors'] as String)),
            year: r['year'] as String?,
            category: r['category'] as String?,
            textContent: r['text_content'] as String? ?? '',
            md5Hash: r['md5_hash'] as String? ?? '',
            chunkCount: r['chunk_count'] as int? ?? 0,
            createdAt: DateTime.parse(r['created_at'] as String),
            risData: r['ris_data'] as String?,
            filePath: r['file_path'] as String?,
            journalName: r['journal_name'] as String?,
            volume: r['volume'] as String?,
            issue: r['issue'] as String?,
            pages: r['pages'] as String?,
            translatedTitle: r['translated_title'] as String?,
            translatedCategory: r['translated_category'] as String?,
            documentType: r['document_type'] as String?,
            publisher: r['publisher'] as String?,
            isbn: r['isbn'] as String?,
            placeOfPublication: r['place_of_publication'] as String?,
          )).toList();
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Process a PDF document: hashing, AI extraction, and storage
  Future<DocumentModel?> processDocument(String filePath, {
    String? providerOverride, 
    String? modelOverride, 
    String? preExtractedText,
    bool Function()? shouldStop,
  }) async {
    if (shouldStop?.call() ?? false) return null;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File PDF tidak ditemukan', filePath);
      }
      final fileName = p.basename(filePath);

      // Step 1: Extract text
      String text;
      if (preExtractedText != null && preExtractedText.trim().isNotEmpty) {
        _log('📄 Menggunakan teks yang sudah diekstrak sebelumnya untuk $fileName...');
        text = preExtractedText;
      } else {
        _log('📄 Mengekstrak teks dari $fileName...');
        text = await _pdfService.extractText(filePath);
      }

      if (text.trim().isEmpty) {
        throw Exception('File PDF kosong atau tidak berisi teks yang terbaca.');
      }
      _log('✅ Teks siap diproses (${text.length} karakter)');

      // Step 2: MD5 Hash check
      _log('🔒 Memeriksa duplikat via MD5...');
      final hash = _hashingService.generateHash(text);
      final isDup = await _vectorStore.hashExists(hash);
      if (isDup) {
        _log('⚠️ DUPLIKAT TERDETEKSI — File ini sudah ada di database.');
        throw DuplicateDocumentException(
            'Dokumen "$fileName" sudah ada di database (MD5 identik).');
      }
      _log('✅ Dokumen unik, melanjutkan...');

      // Step 3: AI Metadata Extraction
      if (shouldStop?.call() ?? false) return null;
      final extractor = AiExtractionService(_apiKeyService);
      final metadata = await extractor.extractMetadata(text, 
          providerOverride: providerOverride, 
          modelOverride: modelOverride,
          onLog: _log);
      if (shouldStop?.call() ?? false) return null;
      _log('✅ Metadata: "${metadata.title}" oleh ${metadata.authors.join(', ')} (${metadata.year ?? 'n.d.'})');
      
      final title = metadata.title;
      final authors = metadata.authors;
      final year = metadata.year;

      // Step 4: Create document model
      final docId = const Uuid().v4();
      final doc = DocumentModel(
        id: docId,
        originalFileName: fileName,
        renamedFileName: '', // Will be updated during archiving
        title: metadata.title,
        authors: metadata.authors,
        year: metadata.year,
        category: metadata.category,
        textContent: text,
        md5Hash: hash,
        createdAt: DateTime.now(),
        journalName: metadata.journalName,
        volume: metadata.volume,
        issue: metadata.issue,
        pages: metadata.pages,
        translatedTitle: metadata.translatedTitle,
        translatedCategory: metadata.translatedCategory,
        documentType: metadata.documentType,
        publisher: metadata.publisher,
        isbn: metadata.isbn,
        placeOfPublication: metadata.placeOfPublication,
      );

      // Step 5: Generate APA filename
      String renamedFile;
      try {
        renamedFile = metadata.suggestedFilename ?? doc.apaFileName;
        renamedFile = renamedFile.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        if (!renamedFile.toLowerCase().endsWith('.pdf')) {
           renamedFile += '.pdf';
        }
        _log('📝 Auto-rename: $renamedFile');
      } catch (e) {
        _log('⚠️ Gagal generate nama APA ($e), menggunakan nama asli.');
        renamedFile = fileName;
      }

      // Step 6: Generate RIS data
      String? risData;
      try {
        risData = risService.generateRis(doc);
        _log('📚 RIS data generated for Mendeley');
      } catch (e) {
        _log('⚠️ Gagal generate data RIS: $e');
      }

      // Step 7: Chunking skipped (Full context mode)
      _log('ℹ️ Mode Full Context: Melewati proses chunking dokumen.');
      List<TextChunk> chunks = [];

      // Step 9: Managed Storage - Copy to internal library
      _log('📂 Mengarsipkan file ke library internal...');
      String? finalPath;
      try {
        final appDir = await getApplicationSupportDirectory();
        final libDir = Directory('${appDir.path}${Platform.pathSeparator}library');
        if (!await libDir.exists()) await libDir.create(recursive: true);

        finalPath = '${libDir.path}${Platform.pathSeparator}$renamedFile';
        await file.copy(finalPath);
        _log('✅ File berhasil diarsipkan ke library.');
      } catch (e) {
        _log('⚠️ Gagal mengarsipkan file fisik: $e');
        // Fallback to original path if copy fails
        finalPath = filePath;
      }

      final updatedDocMap = {
        'id': docId,
        'original_filename': fileName,
        'renamed_filename': renamedFile,
        'title': title,
        'authors': jsonEncode(authors),
        'year': year,
        'category': metadata.category,
        'text_content': text,
        'md5_hash': hash,
        'chunk_count': 0, // Disabled
        'ris_data': risData,
        'file_path': finalPath,
        'journal_name': metadata.journalName,
        'volume': metadata.volume,
        'issue': metadata.issue,
        'pages': metadata.pages,
        'translated_title': metadata.translatedTitle,
        'translated_category': metadata.translatedCategory,
        'document_type': metadata.documentType,
        'publisher': metadata.publisher,
        'isbn': metadata.isbn,
        'place_of_publication': metadata.placeOfPublication,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _vectorStore.insertDocument(updatedDocMap);
      
      // Auto-sync after successful archive
      ref.read(syncProvider.notifier).performSync();

      _log('🎉 Proses selesai untuk: $title');

      // Refresh list
      await _loadDocuments();

      return DocumentModel(
        id: docId,
        originalFileName: fileName,
        renamedFileName: renamedFile,
        title: title,
        authors: authors,
        year: year,
        category: metadata.category,
        textContent: text,
        md5Hash: hash,
        chunkCount: chunks.length,
        createdAt: DateTime.now(),
        risData: risData,
        filePath: finalPath,
        journalName: metadata.journalName,
        volume: metadata.volume,
        issue: metadata.issue,
        pages: metadata.pages,
        documentType: metadata.documentType,
        publisher: metadata.publisher,
        isbn: metadata.isbn,
        placeOfPublication: metadata.placeOfPublication,
      );
    } catch (e, st) {
      _log('❌ Error: $e');
      print('Document processing crash: $e\n$st');
      if (e is DuplicateDocumentException) rethrow;
      rethrow;
    }
  }

  /// Delete a single document and its physical file
  Future<void> deleteDocument(String id, String? physicalPath) async {
    try {
      await _vectorStore.deleteDocument(id);
      if (physicalPath != null) {
        final file = File(physicalPath);
        if (await file.exists()) {
          await file.delete();
          _log('🗑️ File fisik dihapus: ${p.basename(physicalPath)}');
        }
      }
      await _loadDocuments();
    } catch (e) {
      _log('❌ Gagal menghapus dokumen: $e');
    }
  }

  /// Reprocess an existing document to generate new metadata/rename/RIS via AI
  Future<void> reprocessDocument(DocumentModel existingDoc, {
    String? providerOverride, 
    String? modelOverride,
    bool Function()? shouldStop,
  }) async {
    if (shouldStop?.call() ?? false) return;
    try {
      if (existingDoc.filePath == null) throw Exception('File path is null');
      final file = File(existingDoc.filePath!);
      if (!await file.exists()) {
        throw FileSystemException('File PDF tidak ditemukan', existingDoc.filePath!);
      }

      _log('🤖 Sedang memproses ulang: ${existingDoc.title}...');

      // AI Metadata Extraction using existing text
      final extractor = AiExtractionService(_apiKeyService);
      final metadata = await extractor.extractMetadata(existingDoc.textContent, 
          providerOverride: providerOverride, 
          modelOverride: modelOverride,
          onLog: _log);

      _log('✅ Update Metadata: "${metadata.title}" oleh ${metadata.authors.join(', ')}');

      // Create new document model with updated info
      final newDoc = DocumentModel(
        id: existingDoc.id, // KEEP the same ID
        originalFileName: existingDoc.originalFileName,
        renamedFileName: '', // We update this below
        title: metadata.title,
        authors: metadata.authors,
        year: metadata.year,
        category: metadata.category,
        textContent: existingDoc.textContent,
        md5Hash: existingDoc.md5Hash,
        chunkCount: existingDoc.chunkCount,
        createdAt: existingDoc.createdAt,
        journalName: metadata.journalName,
        volume: metadata.volume,
        issue: metadata.issue,
        pages: metadata.pages,
        translatedTitle: metadata.translatedTitle,
        translatedCategory: metadata.translatedCategory,
        filePath: existingDoc.filePath,
        documentType: metadata.documentType,
        publisher: metadata.publisher,
        isbn: metadata.isbn,
        placeOfPublication: metadata.placeOfPublication,
      );

      // Generating new APA filename
      String renamedFile;
      try {
        renamedFile = metadata.suggestedFilename ?? newDoc.apaFileName;
        renamedFile = renamedFile.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        if (!renamedFile.toLowerCase().endsWith('.pdf')) {
           renamedFile += '.pdf';
        }
        _log('📝 Auto-rename baru: $renamedFile');
      } catch (e) {
        _log('⚠️ Gagal generate nama APA baru ($e), menggunakan nama lama.');
        renamedFile = existingDoc.renamedFileName;
      }

      // Generate new RIS data
      String? risData;
      try {
        risData = risService.generateRis(newDoc);
        _log('📚 RIS data baru berhasil dibuat');
      } catch (e) {
        _log('⚠️ Gagal generate data RIS: $e');
        risData = existingDoc.risData;
      }

      // Rename physical file if necessary
      String finalPath = existingDoc.filePath!;
      if (renamedFile != existingDoc.renamedFileName) {
        try {
          final appDir = await getApplicationSupportDirectory();
          final libDir = Directory('${appDir.path}${Platform.pathSeparator}library');
          final targetPath = '${libDir.path}${Platform.pathSeparator}$renamedFile';
          
          if (finalPath != targetPath) {
            await file.rename(targetPath);
            finalPath = targetPath;
            _log('✅ File fisik berhasil diubah namanya.');
          }
        } catch (e) {
          _log('⚠️ Gagal mere-name file fisik: $e');
        }
      }

      // Update in vector store (replaces because of same ID)
      await _vectorStore.insertDocument({
        'id': newDoc.id,
        'original_filename': newDoc.originalFileName,
        'renamed_filename': renamedFile,
        'title': newDoc.title,
        'authors': jsonEncode(newDoc.authors),
        'year': newDoc.year,
        'category': newDoc.category,
        'text_content': newDoc.textContent,
        'md5_hash': newDoc.md5Hash,
        'chunk_count': newDoc.chunkCount,
        'ris_data': risData,
        'file_path': finalPath,
        'journal_name': newDoc.journalName,
        'volume': newDoc.volume,
        'issue': newDoc.issue,
        'pages': newDoc.pages,
        'translated_title': newDoc.translatedTitle,
        'translated_category': newDoc.translatedCategory,
        'document_type': newDoc.documentType,
        'publisher': newDoc.publisher,
        'isbn': newDoc.isbn,
        'place_of_publication': newDoc.placeOfPublication,
        'created_at': newDoc.createdAt.toIso8601String(),
      });

      _log('🎉 Reproses selesai!');
      
      // Refresh list
      await _loadDocuments();
    } catch (e, st) {
      _log('❌ Error: $e');
      print('Reprocessing crash: $e\n$st');
      rethrow;
    }
  }


  /// Wipe the entire library (database + all stored files)
  /// Update document metadata manually
  Future<void> updateDocumentMetadata(DocumentModel doc, Map<String, dynamic> newMeta) async {
    try {
      // Create temporary doc object to generate RIS
      final tempDoc = DocumentModel(
        id: doc.id,
        originalFileName: doc.originalFileName,
        renamedFileName: doc.renamedFileName,
        title: newMeta['title'] ?? doc.title,
        authors: newMeta['authors'] is String 
            ? (newMeta['authors'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : newMeta['authors'] ?? doc.authors,
        year: newMeta['year'] ?? doc.year,
        category: newMeta['category'] ?? doc.category,
        textContent: doc.textContent,
        md5Hash: doc.md5Hash,
        createdAt: doc.createdAt,
        journalName: newMeta['journal_name'] ?? doc.journalName,
        volume: newMeta['volume'] ?? doc.volume,
        issue: newMeta['issue'] ?? doc.issue,
        pages: newMeta['pages'] ?? doc.pages,
        translatedTitle: newMeta['translated_title'] ?? doc.translatedTitle,
        translatedCategory: newMeta['translated_category'] ?? doc.translatedCategory,
        filePath: doc.filePath,
        documentType: newMeta['document_type'] ?? doc.documentType,
        publisher: newMeta['publisher'] ?? doc.publisher,
        isbn: newMeta['isbn'] ?? doc.isbn,
        placeOfPublication: newMeta['place_of_publication'] ?? doc.placeOfPublication,
      );

      String? newRis;
      try {
        newRis = risService.generateRis(tempDoc);
      } catch (e) {
        print('Error generating new RIS: $e');
        newRis = doc.risData;
      }

      // Generate new APA filename
      String renamedFile = doc.renamedFileName;
      try {
        renamedFile = tempDoc.apaFileName;
        renamedFile = renamedFile.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        if (!renamedFile.toLowerCase().endsWith('.pdf')) {
           renamedFile += '.pdf';
        }
      } catch (e) {
        print('Error generating new filename: $e');
      }

      // Rename physical file if necessary
      String finalPath = doc.filePath ?? '';
      if (renamedFile != doc.renamedFileName && finalPath.isNotEmpty) {
        try {
          final file = File(finalPath);
          if (await file.exists()) {
            final newPath = p.join(p.dirname(finalPath), renamedFile);
            if (finalPath != newPath) {
              await file.rename(newPath);
              finalPath = newPath;
              print('✅ File fisik di-rename menjadi: $renamedFile');
            }
          }
        } catch (e) {
          print('⚠️ Gagal me-rename file fisik: $e');
        }
      }

      final updatedDocMap = {
        'id': doc.id,
        'original_filename': doc.originalFileName,
        'renamed_filename': renamedFile,
        'title': tempDoc.title,
        'authors': jsonEncode(tempDoc.authors),
        'year': tempDoc.year,
        'category': tempDoc.category,
        'text_content': doc.textContent,
        'md5_hash': doc.md5Hash,
        'chunk_count': doc.chunkCount,
        'ris_data': newRis, 
        'file_path': finalPath,
        'journal_name': tempDoc.journalName,
        'volume': tempDoc.volume,
        'issue': tempDoc.issue,
        'pages': tempDoc.pages,
        'translated_title': tempDoc.translatedTitle,
        'translated_category': tempDoc.translatedCategory,
        'document_type': tempDoc.documentType,
        'publisher': tempDoc.publisher,
        'isbn': tempDoc.isbn,
        'place_of_publication': tempDoc.placeOfPublication,
        'created_at': doc.createdAt.toIso8601String(),
      };
      
      // Update local SQLite
      await _vectorStore.insertDocument(updatedDocMap);
      
      // Sync with Python RAG backend
      try {
        await http.post(
          Uri.parse('http://localhost:28146/documents/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'doc_id': doc.id,
            'metadata': newMeta,
          }),
        );
      } catch (e) {
        print('Warning: Sync to RAG backend failed (server might be down): $e');
      }

      _log('✅ Metadata dokumen "${newMeta['title'] ?? doc.title}" diperbarui secara manual.');
      await _loadDocuments();
    } catch (e) {
      _log('❌ Gagal memperbarui metadata: $e');
      rethrow;
    }
  }

  Future<void> clearLibrary() async {
    try {
      await _vectorStore.deleteAllDocuments();
      
      final appDir = await getApplicationSupportDirectory();
      final libDir = Directory('${appDir.path}${Platform.pathSeparator}library');
      if (await libDir.exists()) {
        await libDir.delete(recursive: true);
        await libDir.create();
        _log('🧹 Perpustakaan fisik berhasil dikosongkan.');
      }
      
      await _loadDocuments();
      _log('✨ Seluruh database dan perpustakaan telah dihapus.');
    } catch (e) {
      _log('❌ Gagal mengosongkan perpustakaan: $e');
    }
  }

  Future<void> refresh() async {
    await _loadDocuments();
  }
}

class DuplicateDocumentException implements Exception {
  final String message;
  DuplicateDocumentException(this.message);

  @override
  String toString() => message;
}
