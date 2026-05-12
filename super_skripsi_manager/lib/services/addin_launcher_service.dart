import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AddinLauncherService {
  Process? _process;
  bool _isRunning = false;
  final List<String> _logs = [];

  bool get isRunning => _isRunning;
  List<String> get logs => List.unmodifiable(_logs);

  Future<void> startDevServer() async {
    if (_isRunning) return;
    if (!kDebugMode) {
      debugPrint('Add-in dev server is disabled in production. Use the static version served by the bridge.');
      return;
    }

    try {
      // Get the directory of the addin project
      // Assuming structure: d:\SUPER SKRIPSI GANDI\super_skripsi_manager
      // Addin is at: d:\SUPER SKRIPSI GANDI\super_skripsi_addin
      
      final currentDir = Directory.current.path;
      final parentDir = p.dirname(currentDir);
      final addinPath = p.join(parentDir, 'super_skripsi_addin');

      if (!Directory(addinPath).existsSync()) {
        debugPrint('Add-in directory not found at $addinPath');
        return;
      }

      debugPrint('Starting Add-in dev server at $addinPath...');
      
      // Use npm.cmd on Windows, npm on others
      final executable = Platform.isWindows ? 'npm.cmd' : 'npm';
      
      _process = await Process.start(
        executable,
        ['run', 'dev'],
        workingDirectory: addinPath,
        runInShell: true,
      );

      _isRunning = true;

      // Listen to output
      _process!.stdout.transform(utf8.decoder).listen((data) {
        _addLog(data);
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        _addLog('ERROR: $data', isError: true);
      });

      // Handle termination
      _process!.exitCode.then((exitCode) {
        debugPrint('Add-in dev server exited with code $exitCode');
        _isRunning = false;
        _process = null;
      });

    } catch (e) {
      debugPrint('Failed to start Add-in dev server: $e');
      _isRunning = false;
    }
  }

  void stopDevServer() {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      _isRunning = false;
      _process = null;
    }
  }

  void _addLog(String msg, {bool isError = false}) {
    final lines = msg.split('\n');
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      final timestamp = DateTime.now().toString().split(' ').last.substring(0, 8);
      _logs.add('[$timestamp] ${isError ? "!!" : ">>"} $line');
    }
    // Keep last 200 lines
    if (_logs.length > 200) {
      _logs.removeRange(0, _logs.length - 200);
    }
  }
}
