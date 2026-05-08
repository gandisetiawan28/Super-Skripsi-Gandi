import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/pdf_service.dart';
import 'documents_provider.dart';

class ResearchProcessState {
  final List<PendingFileItem> pendingFiles;
  final List<String> logs;
  final bool isProcessing;
  final bool stopRequested;

  ResearchProcessState({
    this.pendingFiles = const [],
    this.logs = const [],
    this.isProcessing = false,
    this.stopRequested = false,
  });

  ResearchProcessState copyWith({
    List<PendingFileItem>? pendingFiles,
    List<String>? logs,
    bool? isProcessing,
    bool? stopRequested,
  }) {
    return ResearchProcessState(
      pendingFiles: pendingFiles ?? this.pendingFiles,
      logs: logs ?? this.logs,
      isProcessing: isProcessing ?? this.isProcessing,
      stopRequested: stopRequested ?? this.stopRequested,
    );
  }
}

class PendingFileItem {
  final PlatformFile file;
  String? extractedText;
  bool isExtracting;
  bool isProcessingAi;
  String? errorMessage;

  PendingFileItem({
    required this.file,
    this.extractedText,
    this.isExtracting = true,
    this.isProcessingAi = false,
    this.errorMessage,
  });

  PendingFileItem copyWith({
    String? extractedText,
    bool? isExtracting,
    bool? isProcessingAi,
    String? errorMessage,
  }) {
    return PendingFileItem(
      file: file,
      extractedText: extractedText ?? this.extractedText,
      isExtracting: isExtracting ?? this.isExtracting,
      isProcessingAi: isProcessingAi ?? this.isProcessingAi,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ResearchProcessNotifier extends StateNotifier<ResearchProcessState> {
  final Ref ref;
  ResearchProcessNotifier(this.ref) : super(ResearchProcessState());

  void addFiles(List<PlatformFile> files) {
    final newItems = files.map((f) => PendingFileItem(file: f)).toList();
    state = state.copyWith(
      pendingFiles: [...state.pendingFiles, ...newItems],
    );
    _startExtractingText(newItems);
  }

  Future<void> _startExtractingText(List<PendingFileItem> items) async {
    final pdfService = PdfService();
    for (var item in items) {
      if (item.file.path == null) continue;
      try {
        final text = await pdfService.extractText(item.file.path!);
        updateFile(item.file.path!, item.copyWith(
          extractedText: text,
          isExtracting: false,
        ));
      } catch (e) {
        updateFile(item.file.path!, item.copyWith(
          errorMessage: e.toString(),
          isExtracting: false,
        ));
      }
    }
  }

  void updateFile(String filePath, PendingFileItem newItem) {
    state = state.copyWith(
      pendingFiles: state.pendingFiles.map((f) => f.file.path == filePath ? newItem : f).toList(),
    );
  }

  void removeFile(String filePath) {
    state = state.copyWith(
      pendingFiles: state.pendingFiles.where((f) => f.file.path != filePath).toList(),
    );
  }

  void addLog(String msg) {
    state = state.copyWith(
      logs: [...state.logs, msg],
    );
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void requestStop() {
    state = state.copyWith(stopRequested: true);
    addLog('🛑 Stop requested by user. Cleaning up...');
  }

  void resetStopRequest() {
    state = state.copyWith(stopRequested: false);
  }

  Future<void> processAllPending() async {
    if (state.isProcessing) return;
    
    setProcessing(true);
    resetStopRequest();
    addLog('🚀 Memulai pemrosesan massal...');

    final itemsToProcess = List<PendingFileItem>.from(state.pendingFiles);
    
    for (var item in itemsToProcess) {
      if (state.stopRequested) {
        addLog('⏹️ Pemrosesan dihentikan oleh user.');
        break;
      }

      if (item.extractedText == null) continue;

      await _processSingleFile(item);
    }

    setProcessing(false);
    if (!state.stopRequested) {
      addLog('✅ Semua file selesai diproses.');
    }
  }

  Future<void> _processSingleFile(PendingFileItem item) async {
    updateFile(item.file.path!, item.copyWith(isProcessingAi: true));
    
    final documentsNotifier = ref.read(documentsProvider.notifier);
    final aiSettings = ref.read(aiExtractionSettingsProvider);

    // Temp log listener
    final prevLogHandler = documentsNotifier.onLogMessage;
    documentsNotifier.onLogMessage = (msg) => addLog(msg);

    try {
      await documentsNotifier.processDocument(
        item.file.path!,
        providerOverride: aiSettings.provider,
        modelOverride: aiSettings.model,
        preExtractedText: item.extractedText,
        shouldStop: () => state.stopRequested,
      );

      if (!state.stopRequested) {
        removeFile(item.file.path!);
      }
    } catch (e) {
      addLog('❌ Error processing ${item.file.name}: $e');
      updateFile(item.file.path!, item.copyWith(isProcessingAi: false, errorMessage: e.toString()));
    } finally {
      documentsNotifier.onLogMessage = prevLogHandler;
    }
  }

  void clearAllPending() {
    state = state.copyWith(pendingFiles: []);
  }
}

final researchProcessProvider = StateNotifierProvider<ResearchProcessNotifier, ResearchProcessState>((ref) {
  return ResearchProcessNotifier(ref);
});
