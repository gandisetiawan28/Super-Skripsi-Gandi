import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/latihan_model.dart';
import '../services/latihan_service.dart';
import '../services/model_fetch_service.dart';
import 'api_keys_provider.dart';
import 'onboarding_provider.dart';
import '../services/sync_service.dart';

// ─── Settings Notifier ────────────────────────────────────────────────────────

class LatihanSettingsNotifier extends StateNotifier<LatihanSettings> {
  final LatihanService _service;

  LatihanSettingsNotifier(this._service) : super(const LatihanSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saved = await _service.loadSettings();
    if (saved != null) state = saved;
  }

  void _save() {
    _service.saveSettings(state);
  }

  void updateFilePath(String path, String name) {
    state = state.copyWith(filePath: path, namaFile: name);
    _save();
  }

  void updateJumlahSoal(int count) {
    state = state.copyWith(jumlahSoal: count);
    _save();
  }

  void updateBabDipilih(List<String> babs) {
    state = state.copyWith(babDipilih: babs);
    _save();
  }

  void updatePersona(PersonaDosen persona) {
    state = state.copyWith(persona: persona);
    _save();
  }

  void updateLevel(LatihanLevel level) {
    state = state.copyWith(level: level);
    _save();
  }

  void updateProvider(String provider) {
    state = state.copyWith(provider: provider, apiKeyName: null, model: null, clearProvider: false, clearModel: true);
    _save();
  }

  void updateApiKeyName(String name) {
    state = state.copyWith(apiKeyName: name, model: null, clearModel: true);
    _save();
  }

  void updateModel(String model) {
    state = state.copyWith(model: model);
    _save();
  }

  void updateTimerAktif(bool active) {
    state = state.copyWith(timerAktif: active);
    _save();
  }

  void updateTimerMenit(int menit) {
    state = state.copyWith(timerMenit: menit);
    _save();
  }
}

final latihanSettingsProvider =
    StateNotifierProvider<LatihanSettingsNotifier, LatihanSettings>(
  (ref) {
    final email = ref.watch(onboardingProvider.select((s) => s.googleEmail));
    final service = LatihanService(email);
    return LatihanSettingsNotifier(service);
  },
);

// ─── Model Fetch Providers ──────────────────────────────────────────────────

final modelFetchServiceProvider = Provider<ModelFetchService>((ref) {
  return ModelFetchService(ref.read(apiKeyServiceProvider));
});

/// Mengambil daftar model secara online berdasarkan provider dan key yang dipilih
final latihanModelsProvider = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(latihanSettingsProvider);
  final apiKeys = ref.watch(apiKeysProvider);
  final fetchService = ref.read(modelFetchServiceProvider);

  if (settings.provider == null) return [];

  // Cari actual API Key string dari nama key yang dipilih
  String? actualKey;
  final keysForProvider = apiKeys[settings.provider!] ?? [];
  if (settings.apiKeyName != null) {
    final match = keysForProvider.firstWhere(
      (k) => k['name'] == settings.apiKeyName,
      orElse: () => {},
    );
    actualKey = match['key'];
  } else if (keysForProvider.isNotEmpty) {
    actualKey = keysForProvider.first['key'];
  }

  // Jika tidak ada key, jangan fetch (kecuali provider tertentu mungkin?)
  if (actualKey == null && settings.provider != 'Localhost') return [];

  return await fetchService.fetchModels(settings.provider!, apiKey: actualKey);
});

// ─── Session Notifier ─────────────────────────────────────────────────────────

class LatihanSessionNotifier extends StateNotifier<LatihanSession> {
  late final LatihanService _service;
  Timer? _timer;
  int _timerSekonSisa = 0;
  Function(int)? onTimerTick;
  Function()? onTimerHabis;

  final Ref ref;

  LatihanSessionNotifier(this.ref) : super(const LatihanSession()) {
    final email = ref.read(onboardingProvider).googleEmail;
    _service = LatihanService(email);
  }

  void addLog(String msg) {
    state = state.copyWith(
      generateLogs: [...state.generateLogs, msg],
    );
  }

  Future<void> startLatihan(LatihanSettings settings) async {
    state = LatihanSession(
      status: LatihanStatus.generating,
      settings: settings,
      generateLogs: ['🎓 Menyiapkan sesi latihan...'],
    );

    try {
      if (settings.filePath == null) throw Exception('File PDF belum dipilih.');

      final pdfText = await _service.extractPdfText(
        settings.filePath!,
        onLog: addLog,
      );

      final soalList = await _service.generateSoal(
        pdfText: pdfText,
        settings: settings,
        onLog: addLog,
      );

      state = state.copyWith(
        soalList: soalList,
        status: LatihanStatus.active,
        jawabanUser: {},
        sudahDijawab: {},
        soalAktifIndex: 0,
        waktuMulai: DateTime.now(),
      );

      if (settings.timerAktif) {
        _startTimer(settings.timerMenit * 60);
      }
    } catch (e) {
      state = state.copyWith(
        status: LatihanStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void _startTimer(int totalDetik) {
    _timerSekonSisa = totalDetik;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerSekonSisa--;
      onTimerTick?.call(_timerSekonSisa);
      if (_timerSekonSisa <= 0) {
        timer.cancel();
        selesaikanLatihan();
      }
    });
  }

  void jawabSoal(int nomorSoal, String pilihan) {
    if (state.status != LatihanStatus.active) return;
    final newJawaban = Map<int, String>.from(state.jawabanUser);
    final newSudah = Map<int, bool>.from(state.sudahDijawab);
    newJawaban[nomorSoal] = pilihan;
    newSudah[nomorSoal] = true;
    state = state.copyWith(jawabanUser: newJawaban, sudahDijawab: newSudah);
  }

  void goToSoal(int index) {
    state = state.copyWith(soalAktifIndex: index);
  }

  Future<void> selesaikanLatihan() async {
    _timer?.cancel();
    final now = DateTime.now();
    state = state.copyWith(
      status: LatihanStatus.selesai,
      waktuSelesai: now,
    );

    // Simpan ke riwayat
    final historyItem = LatihanHistoryItem(
      id: now.millisecondsSinceEpoch.toString(),
      fileName: state.settings.namaFile ?? 'Tanpa Nama',
      date: now,
      score: state.skor,
      totalQuestions: state.soalList.length,
      correctAnswers: state.jumlahBenar,
      soalList: state.soalList,
      jawabanUser: state.jawabanUser,
      settings: state.settings,
    );
    await _service.saveHistory(historyItem);
    ref.read(latihanHistoryProvider.notifier).loadHistory(); // Refresh otomatis
    ref.read(syncProvider.notifier).triggerSync(); // Auto-upload
  }

  void startFromHistory(LatihanHistoryItem item) {
    state = LatihanSession(
      soalList: item.soalList,
      status: LatihanStatus.active,
      waktuMulai: DateTime.now(),
      settings: item.settings,
    );
  }

  void viewHistoryResult(LatihanHistoryItem item) {
    state = LatihanSession(
      soalList: item.soalList,
      jawabanUser: item.jawabanUser,
      sudahDijawab: item.jawabanUser.map((k, v) => MapEntry(k, true)),
      status: LatihanStatus.selesai,
      waktuMulai: item.date,
      waktuSelesai: item.date, // Estimasi saja
      settings: item.settings,
    );
  }

  void reset() {
    _timer?.cancel();
    state = const LatihanSession();
  }
}

final latihanSessionProvider =
    StateNotifierProvider<LatihanSessionNotifier, LatihanSession>(
  (ref) {
    // Watch email to force recreation on logout/login
    ref.watch(onboardingProvider.select((s) => s.googleEmail));
    return LatihanSessionNotifier(ref);
  },
);

// ─── History Notifier ─────────────────────────────────────────────────────────

class LatihanHistoryNotifier extends StateNotifier<List<LatihanHistoryItem>> {
  late final LatihanService _service;
  final Ref ref;

  LatihanHistoryNotifier(this.ref) : super([]) {
    final email = ref.read(onboardingProvider).googleEmail;
    _service = LatihanService(email);
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = await _service.loadHistory();
    // Load latest analysis too
    final savedAnalysis = await _service.loadAnalysis();
    if (savedAnalysis != null) {
      ref.read(aiAnalysisProvider.notifier).state = savedAnalysis;
    }
  }

  Future<void> deleteHistory() async {
    await _service.clearHistory();
    state = [];
    ref.read(syncProvider.notifier).triggerSync();
  }

  Future<void> deleteSingleHistory(String id) async {
    await _service.deleteSingleHistory(id);
    await loadHistory();
    ref.read(syncProvider.notifier).triggerSync();
  }

  Future<void> analyzeProgress(WidgetRef ref) async {
    if (state.isEmpty) return;
    
    final settings = ref.read(latihanSettingsProvider);
    ref.read(aiAnalysisProvider.notifier).state = "Sedang menganalisis progresmu...";
    
    final result = await _service.generateAnalysis(
      history: state,
      provider: settings.provider,
      model: settings.model,
    );
    
    // Simpan hasil analisis ke database untuk sinkronisasi
    await _service.saveAnalysis(result);
    
    ref.read(aiAnalysisProvider.notifier).state = result;
  }
}

final aiAnalysisProvider = StateProvider<String?>((ref) => null);

final latihanHistoryProvider =
    StateNotifierProvider<LatihanHistoryNotifier, List<LatihanHistoryItem>>(
  (ref) {
    // Watch email to force recreation on logout/login
    ref.watch(onboardingProvider.select((s) => s.googleEmail));
    return LatihanHistoryNotifier(ref);
  },
);
