import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  /// Extract text using the best available method for the platform
  Future<String> extractText(String filePath) async {
    if (!kIsWeb && Platform.isAndroid) {
      return await _extractTextNative(filePath);
    } else {
      // Windows/Desktop uses Python for higher precision
      try {
        final result = await _runPythonExtractor(filePath);
        return result['full_text'] as String? ?? '';
      } catch (e) {
        // Fallback to native if Python fails or isn't available
        return await _extractTextNative(filePath);
      }
    }
  }

  /// Extract text page by page
  Future<Map<int, String>> extractTextByPage(String filePath) async {
    if (!kIsWeb && Platform.isAndroid) {
      return await _extractTextByPageNative(filePath);
    } else {
      try {
        final result = await _runPythonExtractor(filePath);
        final pagesData = result['page_texts'] as Map<String, dynamic>? ?? {};
        return pagesData.map((key, value) => MapEntry(int.parse(key), value as String));
      } catch (e) {
        return await _extractTextByPageNative(filePath);
      }
    }
  }

  /// Native Dart extraction (works on Android without Python)
  Future<String> _extractTextNative(String filePath) async {
    try {
      final List<int> bytes = File(filePath).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      print('Native PDF Extraction Error: $e');
      throw Exception('Gagal mengekstrak teks PDF: $e');
    }
  }

  Future<Map<int, String>> _extractTextByPageNative(String filePath) async {
    try {
      final List<int> bytes = File(filePath).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final Map<int, String> pages = {};
      
      for (int i = 0; i < document.pages.count; i++) {
        pages[i + 1] = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      }
      
      document.dispose();
      return pages;
    } catch (e) {
      print('Native Page Extraction Error: $e');
      throw Exception('Gagal mengekstrak halaman PDF: $e');
    }
  }

  /// Update PDF metadata (Properties) - Note: Might not work on Android without specific tools
  Future<void> updateMetadata(String inputPath, String outputPath, Map<String, String> metadata) async {
    if (!kIsWeb && Platform.isAndroid) {
      // On Android, we can use Syncfusion to update metadata
      try {
        final List<int> bytes = File(inputPath).readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        document.documentInformation.title = metadata['title'] ?? document.documentInformation.title;
        document.documentInformation.author = metadata['author'] ?? document.documentInformation.author;
        // ... add other fields if needed
        File(outputPath).writeAsBytesSync(document.saveSync());
        document.dispose();
      } catch (e) {
        throw Exception('Gagal memperbarui metadata PDF di Android: $e');
      }
      return;
    }

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
      final scriptPath = p.join(Directory.current.path, 'lib', 'scripts', 'extract_pdf.py');
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
