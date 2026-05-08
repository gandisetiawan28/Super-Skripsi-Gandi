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

  Future<void> performSync() async {
    if (state.status == SyncStatus.syncing) return;
    
    state = state.copyWith(status: SyncStatus.syncing, error: null, message: 'Menyiapkan sinkronisasi...');
    
    try {
      final appDir = await getApplicationSupportDirectory();
      
      // 1. Snapshot & Sync Database (Dynamic)
      state = state.copyWith(message: 'Upload Database Riset...');
      final safeEmail = SessionUtils.getSafeEmail(_userEmail);
      final dbBaseName = 'vector_store_$safeEmail.db';
      final dbPath = p.join(appDir.path, 'super_skripsi', dbBaseName);
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        final tempDir = await getTemporaryDirectory();
        final snapshotPath = p.join(tempDir.path, 'snapshot_$dbBaseName');
        await dbFile.copy(snapshotPath);
        
        final driveFiles = await _driveService.listAppDataFiles();
        final existingDbFile = driveFiles.firstWhere(
          (f) => f.name == dbBaseName,
          orElse: () => drive.File(),
        );

        await _driveService.uploadFile(
          File(snapshotPath), 
          driveFileId: existingDbFile.id != null ? existingDbFile.id : null,
        );
        
        await File(snapshotPath).delete();
      }

      // 2. Sync Hive Boxes (Latihan History & Cache)
      state = state.copyWith(message: 'Upload Riwayat Latihan...');
      final hiveBoxes = [
        SessionUtils.getDynamicBoxName('latihan_history', _userEmail) + '.hive',
        SessionUtils.getDynamicBoxName('latihan_cache', _userEmail) + '.hive',
        SessionUtils.getDynamicBoxName('latihan_settings', _userEmail) + '.hive',
        SessionUtils.getDynamicBoxName('latihan_analysis', _userEmail) + '.hive',
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

      // 3. Sync Library PDFs
      state = state.copyWith(message: 'Upload Koleksi PDF...');
      final libDir = Directory(p.join(appDir.path, 'library'));
      if (await libDir.exists()) {
        final pdfFiles = libDir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf'));
        final driveFiles = await _driveService.listAppDataFiles();
        
        for (final pdf in pdfFiles) {
          final fileName = p.basename(pdf.path);
          final existing = driveFiles.firstWhere(
            (f) => f.name == fileName,
            orElse: () => drive.File(),
          );
          
          // Only upload if it doesn't exist on Drive
          if (existing.id == null) {
            await _driveService.uploadFile(pdf);
          }
        }
      }

      await _saveMetadata();
      state = state.copyWith(status: SyncStatus.success, message: 'Berhasil disinkronkan');
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString(), message: 'Gagal Sinkronisasi');
    }
  }

  /// Restore everything from Google Drive
  Future<void> performRestore() async {
    if (state.status == SyncStatus.syncing) return;
    state = state.copyWith(status: SyncStatus.syncing, error: null, message: 'Mengecek Backup...');

    try {
      final appDir = await getApplicationSupportDirectory();
      final driveFiles = await _driveService.listAppDataFiles();

      final safeEmail = SessionUtils.getSafeEmail(_userEmail);
      final dbBaseName = 'vector_store_$safeEmail.db';
      final historyBoxName = SessionUtils.getDynamicBoxName('latihan_history', _userEmail) + '.hive';
      final cacheBoxName = SessionUtils.getDynamicBoxName('latihan_cache', _userEmail) + '.hive';
      final settingsBoxName = SessionUtils.getDynamicBoxName('latihan_settings', _userEmail) + '.hive';
      final analysisBoxName = SessionUtils.getDynamicBoxName('latihan_analysis', _userEmail) + '.hive';

      state = state.copyWith(message: 'Mendownload data...');

      for (final driveFile in driveFiles) {
        if (driveFile.id == null || driveFile.name == null) continue;

        if (driveFile.name == dbBaseName) {
          final dbDir = Directory(p.join(appDir.path, 'super_skripsi'));
          if (!await dbDir.exists()) await dbDir.create(recursive: true);
          final target = File(p.join(dbDir.path, driveFile.name));
          await _driveService.downloadFile(driveFile.id!, target);
        } else if (driveFile.name == historyBoxName || driveFile.name == cacheBoxName || driveFile.name == settingsBoxName || driveFile.name == analysisBoxName) {
          final target = File(p.join(appDir.path, driveFile.name));
          await _driveService.downloadFile(driveFile.id!, target);
        } else if (driveFile.name!.endsWith('.pdf')) {
          final libDir = Directory(p.join(appDir.path, 'library'));
          if (!await libDir.exists()) await libDir.create(recursive: true);
          final target = File(p.join(libDir.path, driveFile.name));
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
