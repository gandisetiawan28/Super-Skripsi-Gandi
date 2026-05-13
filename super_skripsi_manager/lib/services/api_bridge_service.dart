import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ApiBridgeService with ChangeNotifier {
  Process? _process;
  void Function(String level, String message)? onLog;
  bool _isIntentionalStop = false;
  final List<String> logs = [];

  void _addLog(String message, {String level = 'BRIDGE'}) {
    final timestamp = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    final logLine = '[$timestamp] [$level] $message';
    logs.add(logLine);
    if (logs.length > 200) logs.removeAt(0);
    
    // Print to console for terminal visibility
    print(logLine);
    
    // Call external listener
    onLog?.call(level, message);
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }
  
  String get _serverPath {
    if (kDebugMode) {
      // Direct development path
      return 'D:\\SUPER SKRIPSI GANDI\\super_skripsi_extension\\api-bridge\\server.js';
    }
    
    // Production path relative to executable
    final exeDir = p.dirname(Platform.resolvedExecutable);
    
    // Inno Setup maps {app}\extension to source ...\super_skripsi_extension
    // So server.js should be at {app}\extension\api-bridge\server.js
    final prodPath = p.join(exeDir, 'extension', 'api-bridge', 'server.js');
    if (File(prodPath).existsSync()) return prodPath;
    
    // Fallback search
    final altPath = p.join(exeDir, '..', 'extension', 'api-bridge', 'server.js');
    if (File(altPath).existsSync()) return altPath;
    
    return prodPath; // Return best guess even if missing for error logging
  }

  String get _nodeExecutable {
    if (kDebugMode) return 'node';
    
    final exeDir = p.dirname(Platform.resolvedExecutable);
    // Portable Node in {app}\node\node.exe
    final portableNode = p.join(exeDir, 'node', 'node.exe');
    
    if (File(portableNode).existsSync()) {
      return portableNode;
    }
    
    // System node fallback
    return 'node';
  }

  bool get isRunning => _process != null;

  Future<void> startServer() async {
    if (_process != null) {
      _addLog('⚠️ Server is already running (PID: ${_process!.pid})');
      return;
    }
    _isIntentionalStop = false;
    _addLog('🚀 Starting Extension Bridge...');

    // 1. Port Cleanup
    try {
      _addLog('🧹 Cleaning up port 3000...');
      await Process.run('powershell', [
        '-Command', 
        'Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force -ErrorAction SilentlyContinue }'
      ]);
    } catch (e) {
      _addLog('⚠️ Cleanup warning: $e');
    }

    // 2. Validate Files
    final path = _serverPath;
    final node = _nodeExecutable;
    
    if (!File(path).existsSync()) {
      _addLog('❌ FATAL: Bridge server file NOT found at: $path');
      _addLog('💡 Check if the installer included the extension folder correctly.');
      return;
    }

    if (node != 'node' && !File(node).existsSync()) {
      _addLog('❌ FATAL: Portable Node.js NOT found at: $node');
      _addLog('💡 Falling back to system "node" command...');
    }

    // 3. Launch Process
    try {
      final workingDir = p.dirname(path);
      _addLog('📂 Target: "$path"');
      _addLog('🤖 Using: "$node"');
      
      _process = await Process.start(
        node,
        [path],
        workingDirectory: workingDir,
        runInShell: false,
      );
      
      _addLog('✅ Bridge process started (PID: ${_process!.pid})');
      notifyListeners();

      // Listen to stdout
      _process!.stdout.transform(utf8.decoder).listen((data) {
        final lines = data.trim().split('\n');
        for (var line in lines) {
           _addLog(line.trim(), level: 'BRIDGE');
        }
      });

      // Listen to stderr
      _process!.stderr.transform(utf8.decoder).listen((data) {
        final lines = data.trim().split('\n');
        for (var line in lines) {
           _addLog('[ERROR] ${line.trim()}');
        }
      });

      _process!.exitCode.then((code) {
        _addLog('⏹️ Bridge exited with code $code');
        _process = null;
        notifyListeners();
        
        if (!_isIntentionalStop) {
          _addLog('⚠️ Unexpected exit. Restarting in 5s...');
          Future.delayed(const Duration(seconds: 5), () => startServer());
        }
      });

    } catch (e) {
      _addLog('❌ FAILED to start process: $e', level: 'ERROR');
      _process = null;
      notifyListeners();
      
      if (!_isIntentionalStop) {
        Future.delayed(const Duration(seconds: 10), () => startServer());
      }
    }
  }

  void stopServer() {
    _isIntentionalStop = true;
    if (_process != null) {
      _addLog('🛑 Stopping bridge server...');
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
}
