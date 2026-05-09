import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/license_validation_service.dart';
import '../services/google_drive_service.dart';

class OnboardingState {
  final int currentStep;
  final bool isCompleted;
  final String? surveySource;
  final String? googleName;
  final String? googleEmail;
  final String? googlePhotoUrl;
  final String? customPhotoPath;
  final bool isAuthenticating;

  OnboardingState({
    this.currentStep = 0,
    this.isCompleted = false,
    this.surveySource,
    this.googleName,
    this.googleEmail,
    this.googlePhotoUrl,
    this.customPhotoPath,
    this.isAuthenticating = false,
  });

  OnboardingState copyWith({
    int? currentStep,
    bool? isCompleted,
    String? surveySource,
    String? googleName,
    String? googleEmail,
    String? googlePhotoUrl,
    String? customPhotoPath,
    bool? isAuthenticating,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isCompleted: isCompleted ?? this.isCompleted,
      surveySource: surveySource ?? this.surveySource,
      googleName: googleName ?? this.googleName,
      googleEmail: googleEmail ?? this.googleEmail,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      customPhotoPath: customPhotoPath ?? this.customPhotoPath,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const String _boxName = 'onboarding_box';
  final Ref _ref;

  OnboardingNotifier(this._ref) : super(OnboardingState()) {
    _loadState();
  }

  Future<void> _loadState() async {
    state = state.copyWith(isAuthenticating: true);
    
    final box = await Hive.openBox(_boxName);
    final isCompleted = box.get('isCompleted', defaultValue: false);
    final surveySource = box.get('surveySource');
    final lastStep = box.get('lastStep', defaultValue: 0);
    
    // Load profile fields
    final googleName = box.get('googleName');
    final googleEmail = box.get('googleEmail');
    final googlePhotoUrl = box.get('googlePhotoUrl');
    final customPhotoPath = box.get('customPhotoPath');

    // Coba restore sesi Google secara diam-diam
    final driveService = _ref.read(googleDriveServiceProvider);
    final sessionRestored = await driveService.restoreSession();
    
    state = state.copyWith(
      isCompleted: isCompleted && sessionRestored, // Hanya anggap komplit jika sesi valid
      surveySource: surveySource,
      currentStep: (isCompleted && sessionRestored) ? 2 : lastStep,
      googleName: googleName,
      googleEmail: googleEmail,
      googlePhotoUrl: googlePhotoUrl,
      customPhotoPath: customPhotoPath,
      isAuthenticating: false,
    );
  }

  Future<void> _saveStep(int step) async {
    final box = await Hive.openBox(_boxName);
    await box.put('lastStep', step);
  }

  void nextStep() {
    if (state.currentStep < 2) {
      final newStep = state.currentStep + 1;
      state = state.copyWith(currentStep: newStep);
      _saveStep(newStep);
    }
  }

  void prevStep() {
    if (state.currentStep > 0) {
      final newStep = state.currentStep - 1;
      state = state.copyWith(currentStep: newStep);
      _saveStep(newStep);
    }
  }

  Future<void> updateGoogleProfile({required String name, required String email, String? photoUrl}) async {
    final box = await Hive.openBox(_boxName);
    await box.put('googleName', name);
    await box.put('googleEmail', email);
    if (photoUrl != null) await box.put('googlePhotoUrl', photoUrl);
    // REMOVED: await box.put('isCompleted', true); // BUG: Ini memicu logout otomatis di AppGate karena lisensi belum ada

    state = state.copyWith(
      googleName: name,
      googleEmail: email,
      googlePhotoUrl: photoUrl,
      // REMOVED: isCompleted: true,
    );
  }

  Future<void> updateProfile({String? name, String? photoPath}) async {
    final box = await Hive.openBox(_boxName);
    if (name != null) {
      await box.put('googleName', name);
      state = state.copyWith(googleName: name);
    }
    if (photoPath != null) {
      await box.put('customPhotoPath', photoPath);
      state = state.copyWith(customPhotoPath: photoPath);
    }
  }

  void setSurveySource(String source) {
    state = state.copyWith(surveySource: source);
  }

  Future<void> completeOnboarding({String? name, String? email}) async {
    // Kirim survey ke Spreadsheet
    if (state.surveySource != null) {
      final finalName = (name != null && name.trim().isNotEmpty) ? name.trim() : ((state.googleName != null && state.googleName!.trim().isNotEmpty) ? state.googleName!.trim() : "Unknown");
      final finalEmail = (email != null && email.trim().isNotEmpty) ? email.trim() : ((state.googleEmail != null && state.googleEmail!.trim().isNotEmpty) ? state.googleEmail!.trim() : "No Email");
      
      // Biarkan error dilempar ke atas agar UI bisa menangkapnya
      await LicenseValidationService().submitSurvey(
        name: finalName,
        email: finalEmail,
        source: state.surveySource!,
      );
    }

    final box = await Hive.openBox(_boxName);
    await box.put('isCompleted', true);
    await box.put('surveySource', state.surveySource);
    state = state.copyWith(isCompleted: true);
  }

  Future<void> resetOnboarding() async {
    // 1. Sign out dari Google Drive Service (Hapus Token & Session)
    await _ref.read(googleDriveServiceProvider).signOut();

    // 2. Hapus data onboarding lokal
    final box = await Hive.openBox(_boxName);
    await box.clear();
    
    state = OnboardingState();
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref);
});
