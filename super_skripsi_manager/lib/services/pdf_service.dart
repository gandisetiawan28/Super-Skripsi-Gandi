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

  /// Update PDF metadata (Properties)
  Future<void> updateMetadata(String inputPath, String outputPath, Map<String, String> metadata) async {
    try {
      final scriptPath = p.join(Directory.current.path, 'lib', 'scripts', 'update_pdf_metadata.py');
      final metaJson = jsonEncode(metadata);
      
      final processResult = await Process.run('py', [
        scriptPath, 
        inputPath, 
        outputPath, 
        metaJson
      ], stdoutEncoding: utf8, stderrEncoding: utf8);
      
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
      // Find the script relative to the current directory
      final scriptPath = p.join(Directory.current.path, 'lib', 'scripts', 'extract_pdf.py');
      
      // Use 'py' launcher on Windows as it's more reliable
      final processResult = await Process.run('py', [scriptPath, filePath], stdoutEncoding: utf8, stderrEncoding: utf8);
      
      if (processResult.exitCode != 0) {
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
}

class ScanPdfException implements Exception {
  final String message;
  ScanPdfException(this.message);
  @override
  String toString() => message;
}
