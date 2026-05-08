import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiUsageData {
  final int remainingTokens;
  final int limitTokens;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final String requestId;
  final String message;
  final bool isActive;
  final String? error;

  ApiUsageData({
    this.remainingTokens = 0,
    this.limitTokens = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.requestId = '-',
    this.message = '',
    this.isActive = false,
    this.error,
  });

  double get tokenUsagePercent => limitTokens > 0 ? (limitTokens - remainingTokens) / limitTokens : 0;
}

class ApiUsageCheckService {
  Future<ApiUsageData> checkUsage(String provider, String apiKey, {String? model}) async {
    try {
      final providerLower = provider.toLowerCase();
      http.Response response;

      if (providerLower.contains('gemini')) {
        return await _checkGemini(apiKey, model: model);
      } else if (providerLower.contains('openai')) {
        response = await _pingOpenAI(apiKey, model ?? "gpt-3.5-turbo");
      } else if (providerLower.contains('groq')) {
        response = await _pingGroq(apiKey, model ?? "llama3-8b-8192");
      } else if (providerLower.contains('cerebras')) {
        response = await _pingCerebras(apiKey, model ?? "llama3.1-8b");
      } else if (providerLower.contains('deepseek')) {
        response = await _pingDeepSeek(apiKey, model ?? "deepseek-chat");
      } else if (providerLower.contains('anthropic')) {
        response = await _pingAnthropic(apiKey, model ?? "claude-3-haiku-20240307");
      } else {
        return ApiUsageData(error: 'Provider tidak didukung untuk cek real-time');
      }

      return _parseHeaders(response);
    } catch (e) {
      return ApiUsageData(isActive: false, error: e.toString());
    }
  }

  Future<ApiUsageData> _checkGemini(String apiKey, {String? model}) async {
    final modelId = model ?? 'gemini-1.5-flash';
    // Ensure the model path is correct. If it already has a prefix, don't add 'models/'
    final modelPath = modelId.contains('/') ? modelId : 'models/$modelId';
    final url = 'https://generativelanguage.googleapis.com/v1beta/$modelPath:generateContent?key=$apiKey';
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": "hi"}]}],
          "generationConfig": {"maxOutputTokens": 1}
        }),
      );
      
      if (res.statusCode == 200) {
        return ApiUsageData(isActive: true, limitTokens: 1000000, remainingTokens: 999999);
      }
      return ApiUsageData(isActive: false, error: 'Status ${res.statusCode}');
    } catch (e) {
      return ApiUsageData(isActive: false, error: e.toString());
    }
  }

  Future<http.Response> _pingOpenAI(String apiKey, String model) async {
    return await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
      }),
    );
  }

  Future<http.Response> _pingGroq(String apiKey, String model) async {
    return await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
      }),
    );
  }

  Future<http.Response> _pingCerebras(String apiKey, String model) async {
    return await http.post(
      Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
      }),
    );
  }

  Future<http.Response> _pingDeepSeek(String apiKey, String model) async {
    return await http.post(
      Uri.parse('https://api.deepseek.com/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": model,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1
      }),
    );
  }

  Future<http.Response> _pingAnthropic(String apiKey, String model) async {
    return await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "model": model,
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "hi"}]
      }),
    );
  }

  ApiUsageData _parseHeaders(http.Response response) {
    final h = response.headers;
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body);
    } catch (_) {}
    
    // Check if unauthorized
    if (response.statusCode == 401 || response.statusCode == 403) {
      return ApiUsageData(isActive: false, error: 'Invalid API Key');
    }

    // Rate Limit Headers (TPM or RPM)
    int remainingTokens = int.tryParse(h['x-ratelimit-remaining-tokens'] ?? h['x-ratelimit-remaining-requests'] ?? '') ?? 0;
    int limitTokens = int.tryParse(h['x-ratelimit-limit-tokens'] ?? h['x-ratelimit-limit-requests'] ?? '') ?? 0;

    // Usage from Body - Adaptive Parsing
    int inputTokens = 0;
    int outputTokens = 0;
    int totalTokens = 0;

    final usage = body['usage'] ?? body['usageMetadata'];
    if (usage != null) {
      // OpenAI, Groq, Cerebras, DeepSeek, Anthropic style
      inputTokens = usage['prompt_tokens'] ?? usage['input_tokens'] ?? usage['promptTokenCount'] ?? 0;
      outputTokens = usage['completion_tokens'] ?? usage['output_tokens'] ?? usage['candidatesTokenCount'] ?? 0;
      totalTokens = usage['total_tokens'] ?? usage['totalTokenCount'] ?? (inputTokens + outputTokens);
    }
    
    // Request ID & Message
    final String requestId = h['x-request-id'] ?? body['id'] ?? '-';
    final String message = response.statusCode == 200 ? 'OK' : (body['error']?['message'] ?? 'Status ${response.statusCode}');

    return ApiUsageData(
      isActive: response.statusCode == 200 || response.statusCode == 429,
      remainingTokens: remainingTokens,
      limitTokens: limitTokens,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      requestId: requestId,
      message: message,
      error: response.statusCode == 200 ? null : message,
    );
  }
}
