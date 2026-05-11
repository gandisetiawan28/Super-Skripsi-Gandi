import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/vector_store_service.dart';
import 'onboarding_provider.dart';

final vectorStoreProvider = Provider<VectorStoreService>((ref) {
  final email = ref.watch(onboardingProvider).googleEmail;
  return VectorStoreService(email);
});
