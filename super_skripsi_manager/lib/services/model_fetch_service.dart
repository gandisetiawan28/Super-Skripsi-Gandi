import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_key_service.dart';

class ModelFetchService {
  final ApiKeyService _apiKeyService;

  ModelFetchService(this._apiKeyService);

  /// Fetch live available models from the provider using the user's API key.
  /// Returns a list of model IDs suitable for chat/generation.
  /// Fetch live available models from the provider using a specific API key.
  /// If [apiKey] is not provided, it uses the first key from the database.
  Future<List<String>> fetchModels(String provider, {String? apiKey}) async {
    String? targetKey = apiKey;
    if (targetKey == null) {
      final keys = await _apiKeyService.getKeys(provider);
      if (keys.isEmpty) return [];
      targetKey = keys.first['key']!;
    }

    try {
      switch (provider) {
        case 'OpenAI':
          return await _fetchOpenAICompatible('https://api.openai.com/v1/models', targetKey, provider);
        case 'Groq':
          return await _fetchOpenAICompatible('https://api.groq.com/openai/v1/models', targetKey, provider);
        case 'Cerebras':
          return await _fetchOpenAICompatible('https://api.cerebras.ai/v1/models', targetKey, provider);
        case 'Google Gemini':
          return await _fetchGeminiModels(targetKey);
        case 'Anthropic Claude':
        case 'Anthropic':
          return await _fetchAnthropicModels(targetKey);
        case 'Localhost':
          // If the key is a full Gemini Flow API endpoint (contains /api/) or port 3000
          if (targetKey.contains('/api') || targetKey.contains(':3000')) {
            return ['gemini', 'openai', 'claude', 'groq', 'deepseek', 'cerebras', 'xai'];
          }
          // Use the key as the URL if it looks like one, otherwise default to Ollama
          final url = targetKey.startsWith('http') 
              ? (targetKey.endsWith('/models') ? targetKey : (targetKey.endsWith('/') ? '${targetKey}models' : '$targetKey/models'))
              : 'http://localhost:11434/v1/models';
          
          try {
            return await _fetchOpenAICompatible(url, 'unused', provider);
          } catch (e) {
            // Fallback for custom local bridges that don't support /models endpoint
            if (e.toString().contains('404')) {
              return ['gemini', 'openai', 'claude', 'groq', 'deepseek', 'cerebras', 'xai'];
            }
            rethrow;
          }
        default:
          return [];
      }
    } catch (e) {
      print('Failed to fetch models for $provider: $e');
      return [];
    }
  }

  Future<List<String>> _fetchOpenAICompatible(String url, String apiKey, String provider) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $apiKey'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List models = data['data'] ?? [];
      
      var result = models.map((m) => m['id'].toString()).toList();
      
      // Filter: hanya model chat/completion yang relevan
      if (provider == 'OpenAI') {
        result = result.where((m) => m.contains('gpt') || m.contains('o1') || m.contains('o3') || m.contains('o4')).toList();
      } else if (provider == 'Groq') {
        result = result.where((m) => !m.endsWith('-tool-use') && !m.contains('whisper')).toList();
      }
      
      result.sort();
      return result;
    }
    throw Exception('API returned ${response.statusCode}');
  }

  Future<List<String>> _fetchGeminiModels(String apiKey) async {
    final response = await http.get(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List models = data['models'] ?? [];
      
      final result = models
          .where((m) {
            final methods = m['supportedGenerationMethods'] as List? ?? [];
            return methods.contains('generateContent');
          })
          .map((m) => m['name'].toString().replaceFirst('models/', ''))
          .toList();
          
      result.sort();
      return result;
    }
    throw Exception('API returned ${response.statusCode}');
  }
  
  Future<List<String>> _fetchAnthropicModels(String apiKey) async {
    final response = await http.get(
      Uri.parse('https://api.anthropic.com/v1/models'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List models = data['data'] ?? [];
      
      final result = models.map((m) => m['id'].toString()).toList();
      result.sort();
      return result;
    }
    throw Exception('API returned ${response.statusCode}');
  }
}
