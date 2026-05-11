import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/license_service.dart';
import '../services/license_validation_service.dart';
import '../models/license_model.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());
final licenseValidationServiceProvider = Provider<LicenseValidationService>((ref) => LicenseValidationService());

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
    _validationTimer = Timer.periodic(const Duration(minutes: 5), (_) => _checkCurrentStatus());
  }

  Future<void> _checkCurrentStatus() async {
    final current = state.value;
    if (current == null) return;

    try {
      final isValid = await _service.reValidateLicense(current);
      if (!isValid) {
        logout();
      }
    } catch (e) {
      debugPrint('Background license check skip: $e');
    }
  }

  Future<void> _loadCached() async {
    state = const AsyncValue.loading();
    try {
      final cached = await _service.getCachedLicense();
      state = AsyncValue.data(cached);
      if (cached != null) {
        await _checkCurrentStatus();
      }
    } catch (e, st) {
      // Jika cache rusak, bersihkan dan anggap tidak ada lisensi
      debugPrint('🚨 Cache Lisensi Rusak: $e');
      await _service.clearLicense();
      state = const AsyncValue.data(null);
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
