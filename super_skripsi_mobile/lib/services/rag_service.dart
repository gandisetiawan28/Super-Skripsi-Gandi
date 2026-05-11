import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Service untuk komunikasi dengan Python RAG Microservice (Versi Cloud)
class RagService {
  static const String _baseUrl = ApiConfig.ragCloudUrl;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 1200);

  // Mobile version doesn't auto-start Python local service
  Future<bool> startService({String? userId}) async {
    print('[RAG Mobile] Menggunakan Cloud Service di $_baseUrl');
    return await isAvailable();
  }

  Future<void> stopService() async {
    // No-op for mobile
  }

  /// Cek apakah Cloud RAG service aktif
  Future<bool> isAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['status'] == 'ok';
    } catch (e) {
      print('[RAG Mobile] Health Check Error: $e');
      return false;
    }
  }

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

  /// Upload dan index dokumen ke Cloud ChromaDB.
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
    final file = File(filePath);
    if (!file.existsSync()) {
      return {'error': 'File tidak ditemukan secara lokal.'};
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

      final streamedRes = await request.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        return {'error': 'HTTP ${res.statusCode}: ${res.body}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> abortIndexing() async {
    try {
      await http.post(Uri.parse('$_baseUrl/abort')).timeout(_timeout);
    } catch (_) {}
  }

  Future<void> cleanupBridge() async {
    // Mobile usually doesn't have local ApiBridge
  }

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
    } catch (_) {
      return [];
    }
  }
}
