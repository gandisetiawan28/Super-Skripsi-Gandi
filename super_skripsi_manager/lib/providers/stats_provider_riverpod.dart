import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_provider.dart';

final statsProvider = ChangeNotifierProvider<StatsProvider>((ref) {
  return StatsProvider();
});
