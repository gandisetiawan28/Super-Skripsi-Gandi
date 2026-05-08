import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/addin_launcher_service.dart';

final addinLauncherService = Provider((ref) => AddinLauncherService());

final addinLauncherProvider = StateNotifierProvider<AddinLauncherNotifier, AddinLauncherState>((ref) {
  final service = ref.watch(addinLauncherService);
  return AddinLauncherNotifier(service);
});

class AddinLauncherState {
  final bool isRunning;
  final List<String> logs;

  AddinLauncherState({
    required this.isRunning,
    required this.logs,
  });

  AddinLauncherState copyWith({
    bool? isRunning,
    List<String>? logs,
  }) {
    return AddinLauncherState(
      isRunning: isRunning ?? this.isRunning,
      logs: logs ?? this.logs,
    );
  }
}

class AddinLauncherNotifier extends StateNotifier<AddinLauncherState> {
  final AddinLauncherService _service;

  AddinLauncherNotifier(this._service)
      : super(AddinLauncherState(isRunning: false, logs: []));

  Future<void> start() async {
    await _service.startDevServer();
    state = state.copyWith(
      isRunning: _service.isRunning,
      logs: _service.logs,
    );
    
    // Periodically update logs if running
    _updateLogs();
  }

  void stop() {
    _service.stopDevServer();
    state = state.copyWith(isRunning: false);
  }

  void _updateLogs() async {
    while (_service.isRunning && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        state = state.copyWith(
          isRunning: _service.isRunning,
          logs: _service.logs,
        );
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
