class ApiKeyModel {
  final String provider;
  final String apiKey;
  final DateTime? lastUpdated;

  ApiKeyModel({
    required this.provider,
    required this.apiKey,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'apiKey': apiKey,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) => ApiKeyModel(
        provider: json['provider'] as String,
        apiKey: json['apiKey'] as String,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : null,
      );

  ApiKeyModel copyWith({String? provider, String? apiKey, DateTime? lastUpdated}) {
    return ApiKeyModel(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static const List<String> supportedProviders = [
    'Google Gemini',
    'OpenAI',
    'Cerebras',
    'Anthropic Claude',
    'Groq',
    'DeepSeek',
    'xAI Grok',
    'Localhost',
  ];

  static const Map<String, String> providerIcons = {
    'Google Gemini': '✦',
    'OpenAI': '◉',
    'Cerebras': '🦾',
    'Anthropic Claude': '◈',
    'Groq': '⚡',
    'DeepSeek': '◆',
    'xAI Grok': '✕',
    'Localhost': '🏠',
  };
}
