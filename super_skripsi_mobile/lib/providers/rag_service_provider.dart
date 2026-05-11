import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rag_service.dart';
import 'onboarding_provider.dart';
import '../services/sync_service.dart';

/// Status Python RAG service
enum RagStatus {
  checking,    // Sedang diperiksa
  starting,    // Sedang distart
  ready,       // Aktif + embedder siap
  loading,     // Aktif tapi embedder masih loading (download model)
  unavailable, // Tidak tersedia
}

class RagState {
  final RagStatus status;
  final int chunkCount;
  final int documentCount;

  const RagState({
    this.status = RagStatus.checking,
    this.chunkCount = 0,
    this.documentCount = 0,
  });

  bool get isActive => status == RagStatus.ready || status == RagStatus.loading;

  String get statusLabel {
    switch (status) {
      case RagStatus.ready:      return '🧠 Semantic';
      case RagStatus.loading:    return '⏳ RAG Loading';
      case RagStatus.starting:   return '🚀 Starting RAG';
      case RagStatus.unavailable:return '📊 TF-IDF';
      case RagStatus.checking:   return '🔍 Checking';
    }
  }

  String get tooltipLabel {
    switch (status) {
      case RagStatus.ready:      return 'Python RAG aktif — Semantic Search (ChromaDB + SentenceTransformers)';
      case RagStatus.loading:    return 'RAG service sedang loading model embedding...';
      case RagStatus.starting:   return 'Memulai Python RAG service...';
      case RagStatus.unavailable:return 'RAG tidak aktif — menggunakan TF-IDF (keyword search)';
      case RagStatus.checking:   return 'Memeriksa status RAG service...';
    }
  }
}

/// Singleton RagService instance
final ragServiceProvider = Provider<RagService>((ref) => RagService());

/// State provider untuk status RAG
class RagStateNotifier extends StateNotifier<RagState> {
  final RagService _service;
  final Ref ref;

  RagStateNotifier(this._service, this.ref) : super(const RagState()) {
    // Listen to sync status changes to auto-refresh
    ref.listen(syncProvider, (previous, next) {
      if (next.status == SyncStatus.success && previous?.status == SyncStatus.syncing) {
        refresh();
      }
    });
  }

  /// Auto-start service dan update state secara berkala
  Future<void> initialize({String? userId}) async {
    if (!mounted) return;
    state = const RagState(status: RagStatus.starting);

    // Coba start service dengan ID User unik
    await _service.startService(userId: userId);
    
    if (!mounted) return;

    // Update status
    await _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final healthData = await _service.getStatus();
    if (!mounted) return;
    if (healthData == null) {
      state = const RagState(status: RagStatus.unavailable);
      return;
    }

    final embedderStatus = healthData['embedder'] as String? ?? 'loading';
    final chunkCount = healthData['total_chunks'] as int? ?? 0;
    final docCount = healthData['total_documents'] as int? ?? 0;

    state = RagState(
      status: embedderStatus == 'ready' ? RagStatus.ready : RagStatus.loading,
      chunkCount: chunkCount,
      documentCount: docCount,
    );
  }

  /// Refresh status (dipanggil periodik dari UI)
  Future<void> refresh() => _refreshStatus();

  /// Index dokumen baru ke ChromaDB
  Future<Map<String, dynamic>?> indexDocument({
    required String filePath,
    required String docId,
    required String title,
    required List<String> authors,
    String? year,
    String? journalName,
    String? apiKey,
    String? provider,
    String? model,
    String? judulSkripsi,
    String? lokasiPenelitian,
    String? kerangkaSkripsi,
    String? systemPrompt, // NEW
  }) async {
    if (!state.isActive) return {'error': 'RAG Service is not active.'};

    final result = await _service.indexDocument(
      filePath: filePath,
      docId: docId,
      title: title,
      authors: authors,
      year: year,
      journalName: journalName,
      apiKey: apiKey,
      provider: provider,
      model: model,
      judulSkripsi: judulSkripsi,
      lokasiPenelitian: lokasiPenelitian,
      kerangkaSkripsi: kerangkaSkripsi,
      systemPrompt: systemPrompt, // NEW
    );


    if (result != null && result['error'] == null) {
      // Update chunk count
      await _refreshStatus();
    }

    return result;
  }

  /// Batalkan proses indexing yang sedang berjalan
  Future<void> abortIndexing() async {
    await _service.abortIndexing();
    await _service.cleanupBridge();
  }

  /// Hapus dokumen dari ChromaDB
  Future<void> deleteDocument(String docId) async {
    await _service.deleteDocument(docId);
    await _refreshStatus();
  }

  @override
  void dispose() {
    _service.stopService();
    super.dispose();
  }
}

final ragStateProvider = StateNotifierProvider<RagStateNotifier, RagState>((ref) {
  // Watch email to force recreation (and stop old service) on logout/login
  final email = ref.watch(onboardingProvider.select((s) => s.googleEmail));
  
  // Generate a unique user ID from email hash
  String? userId;
  if (email != null && email.isNotEmpty) {
    userId = sha256.convert(utf8.encode(email.toLowerCase())).toString().substring(0, 16);
  }

  final service = ref.watch(ragServiceProvider);
  final notifier = RagStateNotifier(service, ref);
  
  // Auto-init only if we have a valid userId
  if (userId != null) {
    notifier.initialize(userId: userId);
  } else {
    // If no user, ensure any old service is stopped
    service.stopService();
  }
  
  return notifier;
});

/// Provider untuk daftar ID dokumen yang sudah terindeks di ChromaDB
final indexedDocsProvider = FutureProvider<List<String>>((ref) async {
  // Watch email agar daftar di-refresh saat ganti user
  ref.watch(onboardingProvider.select((s) => s.googleEmail));
  
  final service = ref.watch(ragServiceProvider);
  final ragState = ref.watch(ragStateProvider);
  
  if (!ragState.isActive) return [];
  return await service.getIndexedDocIds();
});
