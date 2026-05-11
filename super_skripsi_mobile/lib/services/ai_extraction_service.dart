import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_key_service.dart';
import 'model_fetch_service.dart';
import 'package:super_skripsi_mobile/prompts/metadata_extraction_prompt.dart';

class AiExtractionService {
  final ApiKeyService _apiKeyService;
  late final ModelFetchService _modelFetchService;

  AiExtractionService(this._apiKeyService) {
    _modelFetchService = ModelFetchService(_apiKeyService);
  }

  /// Extract metadata from document text using AI
  /// Returns: {title, authors: [], year, category}
  Future<DocumentMetadata> extractMetadata(String textContent, {
    String? providerOverride, 
    String? modelOverride,
    Function(String)? onLog,
  }) async {
    // Gunakan seluruh teks tanpa pemotongan
    final excerpt = textContent;

    // Handle manual override if provided
    if (providerOverride != null) {
      DocumentMetadata? result;
      switch (providerOverride) {
        case 'Google Gemini':
          result = await _tryGemini(excerpt, model: modelOverride);
          break;
        case 'OpenAI':
          result = await _tryOpenAI(excerpt, model: modelOverride);
          break;
        case 'Groq':
          result = await _tryGroq(excerpt, model: modelOverride);
          break;
        case 'Cerebras':
          result = await _tryCerebras(excerpt, model: modelOverride);
          break;
        case 'Localhost':
          result = await _tryLocalhost(excerpt, model: modelOverride);
          break;
      }
      if (result != null) return result;
    }

    final List<Future<DocumentMetadata?> Function(String)> providers;
    
    if (providerOverride != null) {
      // Use only the requested provider
      if (providerOverride == 'Google Gemini') providers = [(e) => _tryGemini(e, onLog: onLog)];
      else if (providerOverride == 'OpenAI') providers = [(e) => _tryOpenAI(e, onLog: onLog)];
      else if (providerOverride == 'Groq') providers = [(e) => _tryGroq(e, onLog: onLog)];
      else if (providerOverride == 'Cerebras') providers = [(e) => _tryCerebras(e, onLog: onLog)];
      else if (providerOverride == 'Localhost') providers = [(e) => _tryLocalhost(e, onLog: onLog)];
      else providers = [(e) => _tryGemini(e, onLog: onLog), (e) => _tryOpenAI(e, onLog: onLog), (e) => _tryGroq(e, onLog: onLog), (e) => _tryCerebras(e, onLog: onLog), (e) => _tryLocalhost(e, onLog: onLog)]..shuffle();
    } else {
      providers = [(e) => _tryGemini(e, onLog: onLog), (e) => _tryOpenAI(e, onLog: onLog), (e) => _tryGroq(e, onLog: onLog), (e) => _tryCerebras(e, onLog: onLog), (e) => _tryLocalhost(e, onLog: onLog)]..shuffle();
    }

    DocumentMetadata? bestResult;

    for (final provider in providers) {
      final providerName = _getProviderName(provider);
      onLog?.call('🔍 Mencoba AI Provider: $providerName...');
      
      try {
        final result = await provider(excerpt);
        if (result != null) {
          // Check if result is "good enough" (has authors and a real title)
          final hasRealAuthor = result.authors.isNotEmpty && 
                                !result.authors.any((a) => a.toLowerCase().contains('unknown'));
          
          final lowerTitle = result.title.toLowerCase();
          final hasRealTitle = result.title != 'Untitled' && 
                              !lowerTitle.contains('volume') &&
                              !lowerTitle.contains('number') &&
                              !lowerTitle.contains('issue') &&
                              !lowerTitle.contains('issn') &&
                              !lowerTitle.contains('jurnal') && 
                              !lowerTitle.contains('halaman') &&
                              !lowerTitle.startsWith('vol.') &&
                              result.title.length > 5;

          if (hasRealAuthor && hasRealTitle) {
            onLog?.call('✨ AI $providerName memberikan hasil berkualitas tinggi.');
            return result;
          }
          
          if (!hasRealTitle) {
            onLog?.call('⚠️ AI $providerName terdistraksi header jurnal ("$lowerTitle"), mencoba provider lain...');
          } else if (!hasRealAuthor) {
            onLog?.call('⚠️ AI $providerName tidak menemukan penulis, mencoba provider lain...');
          } else {
            onLog?.call('⚠️ AI $providerName memberikan hasil kurang lengkap, mencoba provider lain...');
          }
          // Store it as a backup if it's the first result we got
          bestResult ??= result;
        }
      } catch (e) {
        onLog?.call('❌ AI ${_getProviderName(provider)} gagal: $e');
        continue;
      }
    }

    return bestResult ?? _regexFallback(textContent);
  }

  Future<DocumentMetadata?> _tryGemini(String excerpt, {String? model, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Google Gemini');
    if (keys.isEmpty) return null;
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Google Gemini');
      if (models.isEmpty) return null;
      actualModel = models.first;
    }

    Exception? lastException;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) {
          onLog?.call('🔄 Mengganti Key Google Gemini ke #${i + 1}...');
        }

        final response = await http.post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$actualModel:generateContent?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _buildPrompt(excerpt)}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
            },
          }),
        ).timeout(const Duration(minutes: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          try {
            final candidates = data['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) return null;
            
            final content = candidates[0]['content'] as Map?;
            if (content == null) return null;
            
            final parts = content['parts'] as List?;
            if (parts == null || parts.isEmpty) return null;
            
            final text = parts[0]['text'] as String?;
            if (text == null) return null;
            
            return _parseResponse(text);
          } catch (e) {
            throw Exception('JSON Parsing Error: $e');
          }
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) {
            onLog?.call('⚠️ API Error pada Key Google Gemini #${i + 1}, mencoba key berikutnya...');
            continue;
          }
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for Google Gemini');
  }

  Future<DocumentMetadata?> _tryOpenAI(String excerpt, {String? model, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('OpenAI');
    if (keys.isEmpty) return null;
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('OpenAI');
      if (models.isEmpty) return null;
      actualModel = models.first;
    }

    Exception? lastException;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) {
          onLog?.call('🔄 Mengganti Key OpenAI ke #${i + 1}...');
        }

        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': 'You are a metadata extraction assistant. Always respond in valid JSON.'},
              {'role': 'user', 'content': _buildPrompt(excerpt)},
            ],
            'temperature': 0.1,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(minutes: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          try {
            final choices = data['choices'] as List?;
            if (choices == null || choices.isEmpty) return null;
            
            final message = choices[0]['message'] as Map?;
            if (message == null) return null;
            
            final text = message['content'] as String?;
            if (text == null) return null;
            
            return _parseResponse(text);
          } catch (e) {
            throw Exception('JSON Parsing Error: $e');
          }
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) {
            onLog?.call('⚠️ API Error pada Key OpenAI #${i + 1}, mencoba key berikutnya...');
            continue;
          }
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for OpenAI');
  }

  Future<DocumentMetadata?> _tryGroq(String excerpt, {String? model, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Groq');
    if (keys.isEmpty) return null;
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Groq');
      if (models.isEmpty) return null;
      actualModel = models.first;
    }

    Exception? lastException;

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) {
          onLog?.call('🔄 Mengganti Key Groq ke #${i + 1}...');
        }

        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': 'You are a metadata extraction assistant. Always respond in valid JSON.'},
              {'role': 'user', 'content': _buildPrompt(excerpt)},
            ],
            'temperature': 0.1,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(minutes: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          try {
            final choices = data['choices'] as List?;
            if (choices == null || choices.isEmpty) return null;
            
            final message = choices[0]['message'] as Map?;
            if (message == null) return null;
            
            final text = message['content'] as String?;
            if (text == null) return null;
            
            return _parseResponse(text);
          } catch (e) {
            throw Exception('JSON Parsing Error: $e');
          }
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) {
            onLog?.call('⚠️ API Error pada Key Groq #${i + 1}, mencoba key berikutnya...');
            continue;
          }
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for Groq');
  }

  String _buildPrompt(String excerpt) {
    return MetadataExtractionPrompt.build(excerpt);
  }

  DocumentMetadata _parseResponse(String rawText) {
    // Strip markdown code fences if present
    String cleaned = rawText
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final data = jsonDecode(cleaned) as Map<String, dynamic>;

    return DocumentMetadata(
      title: data['title'] as String? ?? 'Untitled',
      authors: data['authors'] != null
          ? List<String>.from(data['authors'] as List)
          : ['Unknown'],
      year: data['year']?.toString(),
      category: data['category']?.toString(),
      translatedTitle: data['translated_title']?.toString(),
      translatedCategory: data['translated_category']?.toString(),
      journalName: data['journal_name']?.toString(),
      volume: data['volume']?.toString(),
      issue: data['issue']?.toString(),
      pages: data['pages']?.toString(),
      suggestedFilename: data['suggested_filename']?.toString(),
      documentType: data['document_type']?.toString(),
      publisher: data['publisher']?.toString(),
      isbn: data['isbn']?.toString(),
      placeOfPublication: data['place_of_publication']?.toString(),
    );
  }

  DocumentMetadata _regexFallback(String text) {
    // Try to extract year
    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(text);
    final year = yearMatch?.group(0);

    // Try to extract title (usually the first prominent line)
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String title = 'Untitled';
    if (lines.isNotEmpty) {
      title = lines.first.trim();
      if (title.length > 100) title = title.substring(0, 100);
    }

    return DocumentMetadata(
      title: title,
      authors: ['Unknown Author'],
      year: year,
      category: null,
    );
  }

  String _getProviderName(Function provider) {
    if (provider == _tryGemini) return 'Google Gemini';
    if (provider == _tryOpenAI) return 'OpenAI';
    if (provider == _tryGroq) return 'Groq';
    if (provider == _tryCerebras) return 'Cerebras';
    if (provider == _tryLocalhost) return 'Localhost';
    return 'Unknown';
  }

  Future<DocumentMetadata?> _tryLocalhost(String excerpt, {String? model, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Localhost');
    if (keys.isEmpty) return null;

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Localhost');
      if (models.isEmpty) return null;
      actualModel = models.first;
    }

    // Smart Selection: Cari key yang namanya mengandung nama model
    int targetIndex = 0;
    for (int i = 0; i < keys.length; i++) {
      final name = (keys[i]['name'] ?? '').toLowerCase();
      final keyVal = (keys[i]['key'] ?? '').toLowerCase();
      if (name.contains(actualModel.toLowerCase()) || keyVal.contains(actualModel.toLowerCase())) {
        targetIndex = i;
        break;
      }
    }

    final keyToUse = keys[targetIndex];
    final urlInput = _normalizeUrl(keyToUse['key']!);
    
    // Bersihkan URL: jika user memasukkan URL lengkap sampai /api/..., 
    // kita ambil base-nya saja agar bisa disesuaikan dengan model yang dipilih di UI
    // Normalisasi: Pastikan baseUrl tidak punya trailing slash dan tidak punya /api di ujungnya
    String baseUrl = urlInput.startsWith('http') ? urlInput.replaceAll(RegExp(r'\/+$'), '') : 'http://$_localHostIp:3000';
    
    // Hapus SEMUA segmen /api di akhir (kasus /api/api/api...)
    while (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4).replaceAll(RegExp(r'\/+$'), '');
    }
    
    final bool isGeminiFlow = baseUrl.contains(':3000') || baseUrl.contains(_localHostIp);
    final String cleanUrl = isGeminiFlow 
        ? '$baseUrl/api/${actualModel.isEmpty ? "gemini" : actualModel}'
        : baseUrl;

    try {
      if (onLog != null) onLog('🌐 Menggunakan Endpoint: $cleanUrl');
      final response = await http.post(
        Uri.parse(cleanUrl),
        headers: {'Content-Type': 'application/json'},
        body: isGeminiFlow 
          ? jsonEncode({'prompt': _buildPrompt(excerpt)})
          : jsonEncode({
              'model': actualModel.isEmpty ? 'llama3' : actualModel,
              'messages': [
                {'role': 'system', 'content': 'You are a metadata extraction assistant. Always respond in valid JSON.'},
                {'role': 'user', 'content': _buildPrompt(excerpt)},
              ],
              'temperature': 0.1,
            }),
      ).timeout(const Duration(minutes: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = isGeminiFlow ? data['result'] : data['choices']?[0]?['message']?['content'];
        
        if (content == null) {
          throw Exception('AI Bridge mengembalikan jawaban kosong (null).');
        }
        
        return _parseResponse(content.toString());
      } else {
        throw Exception('Localhost Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (onLog != null) onLog('❌ Localhost gagal: $e');
      // Untuk Localhost, kita TIDAK melakukan rotasi ke key lain agar tidak membingungkan
      rethrow;
    }
  }

  Future<DocumentMetadata?> _tryCerebras(String excerpt, {String? model, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Cerebras');
    if (keys.isEmpty) return null;
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Cerebras');
      if (models.isEmpty) return null;
      actualModel = models.first;
    }

    Exception? lastException;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) onLog?.call('🔄 Mengganti Key Cerebras ke #${i + 1}...');
        final response = await http.post(
          Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': 'You are a metadata extraction assistant. Always respond in valid JSON.'},
              {'role': 'user', 'content': _buildPrompt(excerpt)},
            ],
            'temperature': 0.1,
          }),
        ).timeout(const Duration(minutes: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return _parseResponse(data['choices'][0]['message']['content'] as String);
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (i < keys.length - 1) continue;
        throw lastException;
      }
    }
    return null;
  }

  // ============================================================================
  // CUSTOM EXTRACTION (RAG THEORY EXTRACTOR)
  // ============================================================================

  /// Extracts structured JSON array data from text using a custom system prompt.
  /// Supports API key rotation and failover just like metadata extraction.
  Future<String> extractCustom({
    required String systemPrompt,
    required String userText,
    required String provider,
    String? model,
    bool isJson = true,
    Function(String)? onLog,
  }) async {
    // Kirim seluruh teks tanpa pemotongan
    final excerpt = userText;
    
    onLog?.call('🌐 Menghubungi $provider (${model ?? "Default Model"})...');

    switch (provider) {
      case 'Google Gemini':
        return await _customGemini(systemPrompt, excerpt, model: model, isJson: isJson, onLog: onLog);
      case 'OpenAI':
        return await _customOpenAI(systemPrompt, excerpt, model: model, isJson: isJson, onLog: onLog);
      case 'Groq':
        return await _customGroq(systemPrompt, excerpt, model: model, isJson: isJson, onLog: onLog);
      case 'Cerebras':
        return await _customCerebras(systemPrompt, excerpt, model: model, isJson: isJson, onLog: onLog);
      case 'Localhost':
        return await _customLocalhost(systemPrompt, excerpt, model: model, isJson: isJson, onLog: onLog);
      default:
        throw Exception('Provider $provider tidak didukung.');
    }
  }

  Future<String> _customCerebras(String systemPrompt, String userText, {String? model, bool isJson = true, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Cerebras');
    if (keys.isEmpty) throw Exception('API Key Cerebras tidak ditemukan.');
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Cerebras');
      if (models.isEmpty) throw Exception('Model Cerebras tidak ditemukan.');
      actualModel = models.first;
    }

    Exception? lastException;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) onLog?.call('🔄 Mengganti Key Cerebras ke #${i + 1}...');
        final response = await http.post(
          Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userText},
            ],
            'temperature': 0.1,
          }),
        ).timeout(const Duration(minutes: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (i < keys.length - 1) continue;
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for Cerebras');
  }

  Future<String> _customGemini(String systemPrompt, String userText, {String? model, bool isJson = true, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Google Gemini');
    if (keys.isEmpty) throw Exception('API Key Google Gemini tidak ditemukan.');
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Google Gemini');
      if (models.isEmpty) throw Exception('Model Google Gemini tidak ditemukan.');
      actualModel = models.first;
    }

    Exception? lastException;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) onLog?.call('🔄 Mengganti Key Google Gemini ke #${i + 1}...');
        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$actualModel:generateContent?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [{'text': systemPrompt}]
            },
            'contents': [
              {'parts': [{'text': userText}]}
            ],
            'generationConfig': {
              'temperature': 0.1, 
              if (isJson) 'responseMimeType': 'application/json'
            },
          }),
        ).timeout(const Duration(minutes: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) continue;
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for Google Gemini');
  }

  Future<String> _customOpenAI(String systemPrompt, String userText, {String? model, bool isJson = true, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('OpenAI');
    if (keys.isEmpty) throw Exception('API Key OpenAI tidak ditemukan.');
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('OpenAI');
      if (models.isEmpty) throw Exception('Model OpenAI tidak ditemukan.');
      actualModel = models.first;
    }

    Exception? lastException;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) onLog?.call('🔄 Mengganti Key OpenAI ke #${i + 1}...');
        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userText},
            ],
            'temperature': 0.1,
            if (isJson) 'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(minutes: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) continue;
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for OpenAI');
  }

  Future<String> _customGroq(String systemPrompt, String userText, {String? model, bool isJson = true, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Groq');
    if (keys.isEmpty) throw Exception('API Key Groq tidak ditemukan.');
    keys.shuffle();

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Groq');
      if (models.isEmpty) throw Exception('Model Groq tidak ditemukan.');
      actualModel = models.first;
    }

    Exception? lastException;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i]['key']!;
      try {
        if (i > 0) onLog?.call('🔄 Mengganti Key Groq ke #${i + 1}...');
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
          body: jsonEncode({
            'model': actualModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userText},
            ],
            'temperature': 0.1,
            if (isJson) 'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(minutes: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        } else {
          throw Exception('API Error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastException = e as Exception;
        if (e.toString().contains('429') || e.toString().contains('401') || e.toString().contains('403') || e.toString().contains('500') || e.toString().contains('503')) {
          if (i < keys.length - 1) continue;
        }
        throw lastException;
      }
    }
    throw lastException ?? Exception('All keys failed for Groq');
  }


  Future<String> _customLocalhost(String systemPrompt, String userText, {String? model, bool isJson = true, Function(String)? onLog}) async {
    final keys = await _apiKeyService.getKeys('Localhost');
    if (keys.isEmpty) throw Exception('Endpoint Localhost tidak ditemukan.');

    String actualModel = model ?? '';
    if (actualModel.isEmpty) {
      final models = await _modelFetchService.fetchModels('Localhost');
      if (models.isEmpty) throw Exception('Model Localhost tidak ditemukan.');
      actualModel = models.first;
    }

    // Smart Selection
    int targetIndex = 0;
    for (int i = 0; i < keys.length; i++) {
      final name = (keys[i]['name'] ?? '').toLowerCase();
      final keyVal = (keys[i]['key'] ?? '').toLowerCase();
      if (name.contains(actualModel.toLowerCase()) || keyVal.contains(actualModel.toLowerCase())) {
        targetIndex = i;
        break;
      }
    }

    final keyToUse = keys[targetIndex];
    final urlInput = _normalizeUrl(keyToUse['key']!);
    
    // Normalisasi: Pastikan baseUrl tidak punya trailing slash dan tidak punya /api di ujungnya
    String baseUrl = urlInput.startsWith('http') ? urlInput.replaceAll(RegExp(r'\/+$'), '') : 'http://$_localHostIp:3000';
    
    // Hapus SEMUA segmen /api di akhir
    while (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4).replaceAll(RegExp(r'\/+$'), '');
    }
    
    final bool isGeminiFlow = baseUrl.contains(':3000') || baseUrl.contains(_localHostIp);
    final String cleanUrl = isGeminiFlow 
        ? '$baseUrl/api/${actualModel.isEmpty ? "gemini" : actualModel}'
        : baseUrl;

    onLog?.call('🔗 Connecting to Localhost Bridge: $cleanUrl');
    try {
      if (onLog != null) onLog('🌐 Menggunakan Endpoint: $cleanUrl');
      final response = await http.post(
        Uri.parse(cleanUrl),
        headers: {'Content-Type': 'application/json'},
        body: isGeminiFlow 
          ? jsonEncode({'prompt': '$systemPrompt\n\n$userText'})
          : jsonEncode({
              'model': actualModel.isEmpty ? 'llama3' : actualModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userText},
              ],
              'temperature': 0.1,
            }),
      ).timeout(const Duration(minutes: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = isGeminiFlow ? data['result'] : data['choices']?[0]?['message']?['content'];
        
        if (content == null) {
          throw Exception('AI Bridge mengembalikan jawaban kosong (null). Pastikan AI di laptop Anda sudah merespon dengan benar.');
        }
        
        return content.toString();
      } else {
        throw Exception('Localhost Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (onLog != null) onLog('❌ Localhost gagal: $e');
      rethrow;
    }
  }

  String get _localHostIp => (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : '127.0.0.1';

  String _normalizeUrl(String url) {
    if (kIsWeb) return url;
    return url.replaceAll('localhost', _localHostIp).replaceAll('127.0.0.1', _localHostIp);
  }
}
class DocumentMetadata {
  final String title;
  final List<String> authors;
  final String? year;
  final String? category;
  final String? translatedTitle;
  final String? translatedCategory;
  final String? journalName;
  final String? volume;
  final String? issue;
  final String? pages;
  final String? suggestedFilename;
  // New fields for document type detection
  final String? documentType;      // JOUR, BOOK, THES, CONF, etc.
  final String? publisher;         // Penerbit (untuk BOOK)
  final String? isbn;              // ISBN (untuk BOOK)
  final String? placeOfPublication; // Kota terbit (untuk BOOK)

  DocumentMetadata({
    required this.title,
    required this.authors,
    this.year,
    this.category,
    this.translatedTitle,
    this.translatedCategory,
    this.journalName,
    this.volume,
    this.issue,
    this.pages,
    this.suggestedFilename,
    this.documentType,
    this.publisher,
    this.isbn,
    this.placeOfPublication,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'authors': authors,
        'year': year,
        'category': category,
        'translated_title': translatedTitle,
        'translated_category': translatedCategory,
        'journalName': journalName,
        'volume': volume,
        'issue': issue,
        'pages': pages,
        'suggestedFilename': suggestedFilename,
        'document_type': documentType,
        'publisher': publisher,
        'isbn': isbn,
        'place_of_publication': placeOfPublication,
      };
}
