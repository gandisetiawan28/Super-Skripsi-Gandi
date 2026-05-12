import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

/// Platform service untuk komunikasi dengan Python RAG Microservice
/// yang berjalan di http://localhost:28146
class RagService {
  static const int _port = 28146;
  static const String _baseUrl = 'http://localhost:$_port';
  static const Duration _timeout = Duration(seconds: 5);
  static const Duration _uploadTimeout = Duration(seconds: 1200);

  Process? _uvicornProcess;
  bool _isStarting = false;
  void Function(String level, String message)? onLog;

  // ── Auto-Start Uvicorn ─────────────────────────────────────────────────────

  /// Start Python RAG service jika belum berjalan.
  /// Menemukan lokasi skrip secara otomatis relatif terhadap exe.
  Future<bool> startService({String? userId}) async {
    if (_isStarting) {
      print('[RAG] Service sedang dalam proses startup, mengabaikan request duplikat.');
      return true;
    }
    
    _isStarting = true;
    try {
      // Cek dulu kalau sudah jalan
      final currentStatus = await getStatus();
      if (currentStatus != null) {
        final activeUser = currentStatus['user_id'] as String?;
        final targetUser = userId ?? 'global';
        
        if (activeUser == targetUser) {
          print('[RAG] Service sudah berjalan untuk user $targetUser.');
          return true;
        } else {
          print('[RAG] 🔄 Service berjalan untuk user $activeUser, tapi butuh $targetUser. Restarting...');
          await stopService();
        }
      }

      // [MOD] Agresif bersihkan port sebelum start
      try {
        print('[RAG] Pembersihan port $_port via PowerShell...');
        await Process.run('powershell', [
          '-Command',
          'Get-NetTCPConnection -LocalPort $_port -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
        ]);
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        print('[RAG] Gagal membersihkan port: $e');
      }

      final ragDir = _findRagServiceDir();
      if (ragDir == null) {
        print('[RAG] ⚠️ Direktori super_skripsi_rag tidak ditemukan. Skip auto-start.');
        return false;
      }

      final mainPy = p.join(ragDir, 'main.py');
      final portablePython = p.join(ragDir, 'python_portable', 'python.exe');
      final venvPython1 = p.join(ragDir, '.venv', 'Scripts', 'python.exe');
      final venvPython2 = p.join(ragDir, 'venv', 'Scripts', 'python.exe');
      
      final usePortable = File(portablePython).existsSync();
      final useVenv1 = File(venvPython1).existsSync();
      final useVenv2 = File(venvPython2).existsSync();
      final useVenv = useVenv1 || useVenv2;
      final venvPython = useVenv1 ? venvPython1 : venvPython2;

      if (!File(mainPy).existsSync()) {
        print('[RAG] ⚠️ main.py tidak ditemukan di $ragDir');
        return false;
      }

      final myPid = pid; // Get current Flutter process PID
      String pythonExe = 'py';
      if (usePortable) pythonExe = portablePython;
      else if (useVenv) pythonExe = venvPython;
      
      print('[RAG] 🚀 Memulai Python RAG service...');
      if (usePortable) print('[RAG] Mode: PORTABLE');
      else if (useVenv) print('[RAG] Mode: VENV');
      else print('[RAG] Mode: SYSTEM');
      print('[RAG] Python Path: $pythonExe');

      _uvicornProcess = await Process.start(
        pythonExe,
        ['-X', 'utf8', '-W', 'ignore', mainPy, 
         '--host', '127.0.0.1', '--port', '$_port',
         '--parent-pid', '$myPid',
         '--user-id', userId ?? ''],
        workingDirectory: ragDir,
      );

      // Tangkap logs dari Python (stdout)
      _uvicornProcess!.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.trim().split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            onLog?.call('RAG', line.trim());
            print('[RAG Python] ${line.trim()}');
          }
        }
      });

      // Tangkap error dari Python (stderr)
      _uvicornProcess!.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.trim().split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            onLog?.call('RAG ERROR', line.trim());
            print('[RAG Python ERROR] ${line.trim()}');

            // [NEW] SELF-HEALING: Jika ada module yang kurang, otomatis instal!
            if (line.contains('ModuleNotFoundError')) {
              onLog?.call('SYSTEM', '🛠️ Mendeteksi modul hilang. Mencoba memperbaiki...');
              _repairDependencies(pythonExe, ragDir);
            }
          }
        }
      });

      // Tunggu hingga service siap (max 300 detik untuk memberi waktu download model)
      for (int i = 0; i < 600; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isAvailable()) {
          print('[RAG] ✅ Python RAG service berhasil distart di port $_port.');
          onLog?.call('RAG', '✅ Python RAG service siap di port $_port');
          return true;
        }
      }

      print('[RAG] ⏱️ Timeout waiting for RAG service. Service mungkin sedang download model.');
      return false;
    } catch (e) {
      print('[RAG] ❌ Gagal start uvicorn: $e');
      return false;
    } finally {
      _isStarting = false;
    }
  }

  /// Hentikan Python RAG service.
  Future<void> stopService() async {
    _uvicornProcess?.kill();
    _uvicornProcess = null;

    // Paksa bersihkan port agar socket dilepas instan oleh Windows
    try {
      await Process.run('powershell', [
        '-Command',
        'Get-NetTCPConnection -LocalPort $_port -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
      ]);
    } catch (_) {}
    
    print('[RAG] ⏹ Python RAG service dihentikan.');
  }

  // ── Health Check ──────────────────────────────────────────────────────────

  /// Cek apakah Python RAG service aktif dan embedder siap.
  Future<bool> isAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah embedder sudah fully ready (bukan sekadar service up).
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Auto-Index PDF ────────────────────────────────────────────────────────

  /// Upload dan index dokumen ke ChromaDB.
  /// Dipanggil otomatis setelah dokumen berhasil disimpan di Research Hub.
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
    String? systemPrompt,
  }) async {
    if (!File(filePath).existsSync()) {
      return {'error': 'File tidak ditemukan: $filePath'};
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['doc_id'] = docId;
      request.fields['title'] = title;
      request.fields['authors'] = jsonEncode(authors);
      request.fields['year'] = year ?? '';
      request.fields['journal_name'] = journalName ?? '';
      
      if (apiKey != null) {
        request.fields['api_key'] = apiKey;
        request.fields['provider'] = provider ?? 'gemini';
        request.fields['model'] = model ?? '';
        
        if (judulSkripsi != null) request.fields['judul_skripsi'] = judulSkripsi;
        if (lokasiPenelitian != null) request.fields['lokasi_penelitian'] = lokasiPenelitian;
        if (kerangkaSkripsi != null) request.fields['kerangka_skripsi'] = kerangkaSkripsi;
        if (systemPrompt != null) request.fields['system_prompt'] = systemPrompt;
      }

      print('[RAG] 📤 Indexing "$title" ke ChromaDB (Structured)...');
      final streamedRes = await request.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        print('[RAG] ✅ Berhasil diindex: ${data['chunk_count']} chunk.');
        return data;
      } else {
        final errorMsg = 'HTTP ${res.statusCode}: ${res.body}';
        print('[RAG] ❌ Index gagal: $errorMsg');
        return {'error': errorMsg};
      }
    } catch (e) {
      final errorMsg = e.toString().contains('Timeout') 
          ? 'Timeout: Proses AI memakan waktu terlalu lama (>20 menit). Cek koneksi atau coba provider lain.'
          : 'Error: $e';
      print('[RAG] ❌ Error indexing: $errorMsg');
      return {'error': errorMsg};
    }
  }

  /// Batalkan proses indexing yang sedang berjalan di Python.
  Future<void> abortIndexing() async {
    try {
      await http.post(Uri.parse('$_baseUrl/abort')).timeout(_timeout);
    } catch (e) {
      print('[RAG] Gagal mengirim sinyal abort: $e');
    }
  }

  /// Bersihkan antrean di ApiBridge (localhost:3000)
  Future<void> cleanupBridge() async {
    try {
      await http.get(Uri.parse('http://localhost:3000/api/clear')).timeout(_timeout);
      print('[RAG] ✅ ApiBridge queue cleared.');
    } catch (_) {}
  }

  /// Hapus dokumen dari ChromaDB.
  Future<bool> deleteDocument(String docId) async {
    try {
      final res = await http
          .delete(Uri.parse('$_baseUrl/documents/$docId'))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ambil daftar ID dokumen yang sudah terindeks di ChromaDB
  Future<List<String>> getIndexedDocIds() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/indexed_docs'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> ids = data['indexed_ids'] ?? [];
        return ids.map((id) => id.toString()).toList();
      }
      return [];
    } catch (e) {
      print('[RAG] ❌ Gagal mengambil indexed_docs: $e');
      return [];
    }
  }

  /// Temukan direktori super_skripsi_rag relatif terhadap exe.
  String? _findRagServiceDir() {
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    
    final candidates = [
      // Development paths
      p.join(Directory.current.path, '..', 'super_skripsi_rag'),
      p.join(Directory.current.path, 'super_skripsi_rag'),
      
      // Production paths (Inno Setup puts it in {app}\rag)
      p.join(exeDir, 'rag'),
      p.join(exeDir, '..', 'rag'),
      p.join(exeDir, 'data', 'flutter_assets', 'rag'),
      
      // Fallback for debug (Only if it exists)
      if (kDebugMode) r'D:\SUPER SKRIPSI GANDI\super_skripsi_rag',
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final dir = Directory(p.normalize(candidate));
      if (dir.existsSync() && File(p.join(dir.path, 'main.py')).existsSync()) {
        debugPrint('[RAG] Found RAG service directory at: ${dir.path}');
        return dir.path;
      }
    }
    return null;
  }

  bool _isRepairing = false;

  /// Mencoba memperbaiki dependensi yang hilang secara otomatis.
  Future<void> _repairDependencies(String pythonExe, String ragDir) async {
    if (_isRepairing) return;
    _isRepairing = true;

    try {
      print('[RAG] 🛠️ Menjalankan perbaikan dependensi otomatis...');
      final result = await Process.run(
        pythonExe,
        ['-m', 'pip', 'install', '-r', 'requirements.txt'],
        workingDirectory: ragDir,
      );

      if (result.exitCode == 0) {
        onLog?.call('SYSTEM', '✅ Perbaikan selesai. Silakan restart fitur AI.');
        print('[RAG] ✅ Perbaikan berhasil.');
      } else {
        onLog?.call('SYSTEM', '❌ Perbaikan gagal: ${result.stderr}');
        print('[RAG] ❌ Perbaikan gagal: ${result.stderr}');
      }
    } catch (e) {
      print('[RAG] ❌ Error saat repair: $e');
    } finally {
      _isRepairing = false;
    }
  }
}
