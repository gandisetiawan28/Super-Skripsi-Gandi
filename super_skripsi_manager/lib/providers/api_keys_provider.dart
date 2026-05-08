import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_key_service.dart';
import 'onboarding_provider.dart';

final apiKeyServiceProvider = Provider<ApiKeyService>((ref) {
  final email = ref.watch(onboardingProvider).googleEmail;
  return ApiKeyService(email);
});

final apiKeysProvider =
    StateNotifierProvider<ApiKeysNotifier, Map<String, List<Map<String, String>>>>((ref) {
  final service = ref.watch(apiKeyServiceProvider);
  return ApiKeysNotifier(service);
});

class ApiKeysNotifier extends StateNotifier<Map<String, List<Map<String, String>>>> {
  final ApiKeyService _service;

  ApiKeysNotifier(this._service) : super({}) {
    loadKeys();
  }

  Future<void> loadKeys() async {
    await _service.seedDefaults();
    final keysMap = await _service.getAllKeysMap();
    state = keysMap;
  }

  Future<void> saveKey(String provider, String name, String apiKey) async {
    await _service.saveKey(provider, name, apiKey);
    await loadKeys();
  }

  Future<void> deleteKey(String provider, int index) async {
    await _service.deleteKey(provider, index);
    await loadKeys();
  }

  Future<void> deleteProvider(String provider) async {
    await _service.deleteProvider(provider);
    await loadKeys();
  }
}
