import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ApiBridgeService with ChangeNotifier {
  Process? _process;
  final String _serverPath = 'D:\\SUPER SKRIPSI GANDI\\super_skripsi_extension\\api-bridge\\server.js';

  bool _isIntentionalStop = false;

  Future<void> startServer() async {
    if (_process != null) {
      debugPrint('[ApiBridge] Server is already running.');
      return;
    }
    _isIntentionalStop = false;

    try {
      debugPrint('[ApiBridge] Cleaning up port 3000 via PowerShell...');
      // Escape $ sign so Dart doesn't treat it as interpolation
      await Process.run('powershell', [
        '-Command', 
        'Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
      ]);
    } catch (e) {
      debugPrint('[ApiBridge] Cleanup warning: $e');
    }

    try {
      debugPrint('[ApiBridge] Starting Node.js server at $_serverPath...');
      
      _process = await Process.start(
        'node',
        [_serverPath],
        runInShell: true,
      );
      notifyListeners();

      // Listen to stdout
      _process!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[ApiBridge STDOUT] ${data.trim()}');
      });

      // Listen to stderr
      _process!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[ApiBridge STDERR] ${data.trim()}');
      });

      _process!.exitCode.then((code) {
        debugPrint('[ApiBridge] Server exited with code $code');
        _process = null;
        notifyListeners();
        if (!_isIntentionalStop) {
          debugPrint('[ApiBridge] Server stopped unexpectedly. Restarting in 2 seconds...');
          Future.delayed(const Duration(seconds: 2), () => startServer());
        }
      });

      debugPrint('[ApiBridge] Server process started.');
    } catch (e) {
      debugPrint('[ApiBridge ERROR] Failed to start server: $e');
      _process = null;
      notifyListeners();
      if (!_isIntentionalStop) {
        Future.delayed(const Duration(seconds: 5), () => startServer());
      }
    }
  }

  void stopServer() {
    _isIntentionalStop = true;
    if (_process != null) {
      debugPrint('[ApiBridge] Stopping server...');
      _process!.kill();
      _process = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }

  bool get isRunning => _process != null;
}
