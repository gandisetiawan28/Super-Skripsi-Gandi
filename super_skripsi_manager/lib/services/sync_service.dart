import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'google_drive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../utils/session_utils.dart';
import '../providers/onboarding_provider.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSync;
  final String? error;
  final String? message;

  SyncState({this.status = SyncStatus.idle, this.lastSync, this.error, this.message});

  SyncState copyWith({SyncStatus? status, DateTime? lastSync, String? error, String? message}) {
    return SyncState(
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      error: error ?? this.error,
      message: message ?? this.message,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  final GoogleDriveService _driveService;
  final String? _userEmail;
  static const String _syncBoxBaseName = 'sync_metadata';

  Timer? _autoSyncTimer;

  SyncService(this._driveService, this._userEmail) : super(SyncState()) {
    _loadMetadata().then((_) {
      if (_userEmail != null) {
        // Auto-restore then Sync on startup
        performRestore().then((_) => performSync());
      }
    });

    // Start periodic sync every 10 minutes
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_userEmail != null) performSync();
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_syncBoxBaseName, _userEmail));
    final lastSyncMillis = box.get('lastSync');
    if (lastSyncMillis != null) {
      state = state.copyWith(lastSync: DateTime.fromMillisecondsSinceEpoch(lastSyncMillis));
    }
  }

  Future<void> _saveMetadata() async {
    final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_syncBoxBaseName, _userEmail));
    final now = DateTime.now();
    await box.put('lastSync', now.millisecondsSinceEpoch);
    state = state.copyWith(lastSync: now);
  }


  /// Restore everything from Google Drive
  Future<String> _getProjectRoot() async {
    // RAG engine uses UserHome/.super_skripsi
    final home = Platform.isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
    final root = p.join(home!, '.super_skripsi');
    final dir = Directory(root);
    if (!await dir.exists()) await dir.create(recursive: true);
    return root;
  }

  Future<void> performSync() async {
    if (state.status == SyncStatus.syncing) return;
    if (_userEmail == null) return;
    
    state = state.copyWith(status: SyncStatus.syncing, error: null, message: 'Menyiapkan sinkronisasi...');
    
    try {
      final projectRoot = await _getProjectRoot();
      final safeEmail = SessionUtils.getSafeEmail(_userEmail);
      final userFolder = p.join(projectRoot, 'users', safeEmail);
      final uploadDir = p.join(userFolder, 'uploaded_pdfs');
      final registryPath = p.join(userFolder, 'doc_registry.json');
      
      // Ensure folders exist
      await Directory(uploadDir).create(recursive: true);

      // 1. Sync Registry (Paling Penting agar AI tahu daftar dokumen)
      state = state.copyWith(message: 'Upload Daftar Dokumen...');
      final registryFile = File(registryPath);
      if (await registryFile.exists()) {
        final driveFiles = await _driveService.listAppDataFiles();
        final remoteName = 'doc_registry_$safeEmail.json';
        final existing = driveFiles.firstWhere(
          (f) => f.name == remoteName,
          orElse: () => drive.File(),
        );
        await _driveService.uploadFile(registryFile, driveFileId: existing.id);
      }

      // 2. Sync Library PDFs (Hanya file yang ada di registry)
      state = state.copyWith(message: 'Upload Koleksi PDF...');
      final dir = Directory(uploadDir);
      if (await dir.exists()) {
        final pdfFiles = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));
        final driveFiles = await _driveService.listAppDataFiles();
        
        for (final pdf in pdfFiles) {
          final fileName = p.basename(pdf.path);
          // Prefix dengan email agar tidak tabrakan antar user di AppData Google Drive
          final remotePdfName = 'pdf_${safeEmail}_$fileName';
          
          final existing = driveFiles.firstWhere(
            (f) => f.name == remotePdfName,
            orElse: () => drive.File(),
          );
          
          if (existing.id == null) {
            await _driveService.uploadFile(pdf);
          }
        }
      }

      // 3. Sync Hive Boxes (Latihan & Settings)
      state = state.copyWith(message: 'Upload Data App...');
      final appDir = await getApplicationSupportDirectory();
      final hiveBoxes = [
        SessionUtils.getDynamicBoxName('latihan_history', _userEmail) + '.hive',
        SessionUtils.getDynamicBoxName('latihan_cache', _userEmail) + '.hive',
        SessionUtils.getDynamicBoxName('latihan_settings', _userEmail) + '.hive',
      ];

      for (final boxName in hiveBoxes) {
        final boxPath = p.join(appDir.path, boxName);
        final boxFile = File(boxPath);
        if (await boxFile.exists()) {
          final driveFiles = await _driveService.listAppDataFiles();
          final existing = driveFiles.firstWhere(
            (f) => f.name == boxName,
            orElse: () => drive.File(),
          );
          await _driveService.uploadFile(boxFile, driveFileId: existing.id);
        }
      }

      await _saveMetadata();
      state = state.copyWith(status: SyncStatus.success, message: 'Berhasil disinkronkan');
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString(), message: 'Gagal Sinkronisasi');
    }
  }

  Future<void> performRestore() async {
    if (state.status == SyncStatus.syncing) return;
    if (_userEmail == null) return;
    
    state = state.copyWith(status: SyncStatus.syncing, error: null, message: 'Mengecek Backup...');

    try {
      final projectRoot = await _getProjectRoot();
      final safeEmail = SessionUtils.getSafeEmail(_userEmail);
      final userFolder = p.join(projectRoot, 'users', safeEmail);
      final uploadDir = p.join(userFolder, 'uploaded_pdfs');
      final registryPath = p.join(userFolder, 'doc_registry.json');

      await Directory(uploadDir).create(recursive: true);
      
      final driveFiles = await _driveService.listAppDataFiles();
      state = state.copyWith(message: 'Mendownload data...');

      final remoteRegistryName = 'doc_registry_$safeEmail.json';
      final remotePdfPrefix = 'pdf_${safeEmail}_';

      for (final driveFile in driveFiles) {
        if (driveFile.id == null || driveFile.name == null) continue;

        // Restore Registry
        if (driveFile.name == remoteRegistryName) {
          await _driveService.downloadFile(driveFile.id!, File(registryPath));
        } 
        // Restore PDFs
        else if (driveFile.name!.startsWith(remotePdfPrefix)) {
          final localName = driveFile.name!.replaceFirst(remotePdfPrefix, '');
          final target = File(p.join(uploadDir, localName));
          if (!await target.exists()) {
            await _driveService.downloadFile(driveFile.id!, target);
          }
        }
        // Restore Hive Boxes
        else if (driveFile.name!.contains('.hive')) {
          final appDir = await getApplicationSupportDirectory();
          final target = File(p.join(appDir.path, driveFile.name!));
          await _driveService.downloadFile(driveFile.id!, target);
        }
      }

      state = state.copyWith(status: SyncStatus.success, message: 'Data dipulihkan');
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString(), message: 'Gagal Restore');
    }
  }

  /// Trigger sync manually or from other services
  void triggerSync() {
    performSync();
  }

  Future<void> clearMetadata() async {
    final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_syncBoxBaseName, _userEmail));
    await box.clear();
    state = SyncState();
  }
}


final syncProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  final driveService = ref.watch(googleDriveServiceProvider);
  final email = ref.watch(onboardingProvider).googleEmail;
  return SyncService(driveService, email);
});
