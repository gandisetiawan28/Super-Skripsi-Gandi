import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_server_service.dart';
import '../services/api_key_service.dart';
import '../services/vector_store_service.dart';

import '../services/rag_service.dart';
import 'rag_service_provider.dart';

import 'onboarding_provider.dart';

final serverProvider =
    StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  final email = ref.watch(onboardingProvider).googleEmail;
  final apiKeyService = ref.read(Provider<ApiKeyService>((ref) => ApiKeyService(email)));
  final vectorStore = ref.read(Provider<VectorStoreService>((ref) => VectorStoreService(email)));
  final ragService = ref.read(ragServiceProvider);
  return ServerNotifier(apiKeyService, vectorStore, ragService);
});

class ServerState {
  final bool isRunning;
  final int port;
  final List<String> logs;

  ServerState({
    this.isRunning = false,
    this.port = LocalServerService.defaultPort,
    this.logs = const [],
  });

  ServerState copyWith({bool? isRunning, int? port, List<String>? logs}) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      logs: logs ?? this.logs,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  late final LocalServerService _server;

  ServerNotifier(ApiKeyService apiKeyService, VectorStoreService vectorStore, RagService ragService)
      : super(ServerState()) {
    _server = LocalServerService(apiKeyService, vectorStore);
    
    void handleLog(String level, String message) {
      if (!mounted) return;
      final newLogs = [...state.logs, '[$level] $message'];
      if (newLogs.length > 300) {
        state = state.copyWith(logs: newLogs.sublist(newLogs.length - 300));
      } else {
        state = state.copyWith(logs: newLogs);
      }
    }

    _server.onLog = handleLog;
    ragService.onLog = handleLog;
  }

  Future<void> startServer({int? port}) async {
    try {
      await _server.start(port: port ?? LocalServerService.defaultPort);
      if (!mounted) return;
      state = state.copyWith(isRunning: true, port: _server.port);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isRunning: false,
        logs: [...state.logs, '[error] Failed to start: $e'],
      );
    }
  }

  Future<void> stopServer() async {
    await _server.stop();
    if (!mounted) return;
    state = state.copyWith(isRunning: false);
  }

  void clearLogs() {
    if (!mounted) return;
    state = state.copyWith(logs: []);
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
