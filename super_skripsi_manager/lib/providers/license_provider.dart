import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../services/license_validation_service.dart';
import '../models/license_model.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());
final licenseValidationServiceProvider = Provider<LicenseValidationService>((ref) => LicenseValidationService());

// Provider untuk memantau status blokir brute-force secara real-time
final licenseBlockProvider = StateProvider<Map<String, dynamic>>((ref) => {"is_blocked": false});

// Timer untuk mengupdate countdown blokir setiap detik
final licenseBlockTimerProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final validationService = ref.read(licenseValidationServiceProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await validationService.checkBlockStatus();
  }).asyncMap((event) => event);
});

final licenseStateProvider =
    StateNotifierProvider<LicenseNotifier, AsyncValue<LicenseModel?>>((ref) {
  return LicenseNotifier(ref);
});

class LicenseNotifier extends StateNotifier<AsyncValue<LicenseModel?>> {
  final Ref _ref;
  late final LicenseService _service;
  Timer? _validationTimer;
  
  LicenseNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _service = _ref.read(licenseServiceProvider);
    _loadCached().then((_) => _startPeriodicValidation());
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicValidation() {
    _validationTimer?.cancel();
    // Cek setiap 5 menit (300 detik) - Jangan terlalu sering agar tidak kena rate limit
    _validationTimer = Timer.periodic(const Duration(minutes: 5), (_) => _checkCurrentStatus());
  }

  Future<void> _checkCurrentStatus() async {
    final current = state.value;
    if (current == null) return;

    try {
      final isValid = await _service.reValidateLicense(current);
      if (!isValid) {
        // Jika tidak valid, lempar ke login
        logout();
      }
    } catch (e) {
      // Diamkan error jika hanya masalah rate limit atau koneksi di background
      debugPrint('Background license check skip: $e');
    }
  }

  Future<void> _loadCached() async {
    state = const AsyncValue.loading();
    try {
      final cached = await _service.getCachedLicense();
      state = AsyncValue.data(cached);
      if (cached != null) {
        // Cek sekali saat startup juga
        await _checkCurrentStatus();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> validate({required String name, required String key}) async {
    state = const AsyncValue.loading();
    try {
      final license = await _service.validateLicense(key, name);
      state = AsyncValue.data(license);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _service.clearLicense();
    state = const AsyncValue.data(null);
  }
}
