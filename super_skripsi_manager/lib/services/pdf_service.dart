import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class PdfService {
  /// Extract text using Python PyMuPDF (stabler than native Dart libs)
  Future<String> extractText(String filePath) async {
    final result = await _runPythonExtractor(filePath);
    return result['full_text'] as String? ?? '';
  }

  /// Extract text page by page using Python
  Future<Map<int, String>> extractTextByPage(String filePath) async {
    final result = await _runPythonExtractor(filePath);
    final pagesData = result['page_texts'] as Map<String, dynamic>? ?? {};
    
    // Convert keys from String to int
    return pagesData.map((key, value) => MapEntry(int.parse(key), value as String));
  }

  /// Helper to find script path reliably across dev/prod
  String _getScriptPath(String scriptName) {
    // Check if we are running from a built executable (production)
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    
    // In production, scripts are in {app}/lib/scripts/
    final prodPath = p.join(exeDir, 'lib', 'scripts', scriptName);
    if (File(prodPath).existsSync()) {
      return prodPath;
    }
    
    // Fallback for development (current directory)
    return p.join(Directory.current.path, 'lib', 'scripts', scriptName);
  }

  /// Update PDF metadata (Properties)
  Future<void> updateMetadata(String inputPath, String outputPath, Map<String, String> metadata) async {
    try {
      final scriptPath = _getScriptPath('update_pdf_metadata.py');
      final metaJson = jsonEncode(metadata);
      final pythonExe = _getPythonPath();
      
      final processResult = await Process.run(
        pythonExe, 
        [scriptPath, inputPath, outputPath, metaJson], 
        stdoutEncoding: utf8, 
        stderrEncoding: utf8
      );
      
      if (processResult.exitCode != 0) {
        throw Exception('Failed to update PDF metadata: ${processResult.stderr}');
      }
    } catch (e) {
      print('PDF Metadata Update Error: $e');
      throw Exception('Gagal memperbarui metadata PDF: $e');
    }
  }

  Future<Map<String, dynamic>> _runPythonExtractor(String filePath) async {
    try {
      final scriptPath = _getScriptPath('extract_pdf.py');
      final pythonExe = _getPythonPath();
      
      print('[PDF] Running extractor with: $pythonExe');
      print('[PDF] Script: $scriptPath');
      
      // Use Process.run with explicit arguments to handle spaces correctly
      final processResult = await Process.run(
        pythonExe, 
        [scriptPath, filePath], 
        stdoutEncoding: utf8, 
        stderrEncoding: utf8
      );
      
      if (processResult.exitCode != 0) {
        print('[PDF] Python Error: ${processResult.stderr}');
        throw Exception('Python extraction failed: ${processResult.stderr}');
      }
      
      final output = processResult.stdout.toString().trim();
      if (output.isEmpty) {
        throw Exception('No output from Python extraction.');
      }
      
      return jsonDecode(output) as Map<String, dynamic>;
    } catch (e) {
      print('PDF Extraction Error: $e');
      throw Exception('Gagal mengekstrak teks PDF via Python: $e');
    }
  }

  /// Discover the best python executable available
  String _getPythonPath() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    
    // Candidates for python executable
    final candidates = [
      // 1. Portable Python inside rag folder (Production)
      p.join(exeDir, 'rag', 'python_portable', 'python.exe'),
      p.join(exeDir, 'rag', '.venv', 'Scripts', 'python.exe'),
      
      // 2. Development paths
      p.join(Directory.current.path, '..', 'super_skripsi_rag', '.venv', 'Scripts', 'python.exe'),
      p.join(Directory.current.path, 'super_skripsi_rag', '.venv', 'Scripts', 'python.exe'),
      
      // 3. Absolute dev path (for debug)
      r'D:\SUPER SKRIPSI GANDI\super_skripsi_rag\.venv\Scripts\python.exe',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // Fallback to system launcher
    return 'py';
  }
}

class ScanPdfException implements Exception {
  final String message;
  ScanPdfException(this.message);
  @override
  String toString() => message;
}
