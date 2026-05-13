import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_bridge_service.dart';

final apiBridgeProvider = ChangeNotifierProvider<ApiBridgeService>((ref) {
  return ApiBridgeService();
});
