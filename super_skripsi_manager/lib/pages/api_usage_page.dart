import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/api_keys_provider.dart';
import '../models/api_key_model.dart';
import '../services/api_usage_check_service.dart';
import '../services/model_fetch_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ApiUsagePage extends ConsumerStatefulWidget {
  const ApiUsagePage({super.key});

  @override
  ConsumerState<ApiUsagePage> createState() => _ApiUsagePageState();
}

class _ApiUsagePageState extends ConsumerState<ApiUsagePage> {
  final ApiUsageCheckService _checkService = ApiUsageCheckService();
  late final ModelFetchService _modelService;
  final Map<String, List<String>> _modelData = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, bool> _showModels = {};
  final Map<String, Map<String, ApiUsageData>> _modelUsageData = {};
  final Map<String, Map<String, bool>> _modelLoading = {};

  @override
  void initState() {
    super.initState();
    _modelService = ModelFetchService(ref.read(apiKeyServiceProvider));
  }

  Future<void> _refreshUsage(String provider, String name, String apiKey) async {
    final id = '$provider-$name-$apiKey';
    setState(() => _isLoading[id] = true);
    
    try {
      // First fetch the list of models
      final models = await _modelService.fetchModels(provider, apiKey: apiKey);
      setState(() {
        _modelData[id] = models;
        _isLoading[id] = false;
        _showModels[id] = true; // Auto-show models after refresh
      });
    } catch (e) {
      setState(() => _isLoading[id] = false);
    }
  }

  Future<void> _checkModelSpecific(String provider, String apiKey, String modelId, String keyId) async {
    setState(() {
      _modelLoading[keyId] ??= {};
      _modelLoading[keyId]![modelId] = true;
    });

    try {
      final data = await _checkService.checkUsage(provider, apiKey, model: modelId);
      setState(() {
        _modelUsageData[keyId] ??= {};
        _modelUsageData[keyId]![modelId] = data;
        _modelLoading[keyId]![modelId] = false;
      });
    } catch (e) {
      setState(() {
        _modelLoading[keyId]![modelId] = false;
      });
    }
  }

  Future<void> _checkAllModels(String provider, String apiKey, String keyId) async {
    final models = _modelData[keyId] ?? [];
    if (models.isEmpty) return;

    for (final model in models) {
      await _checkModelSpecific(provider, apiKey, model, keyId);
      // Safety delay to avoid spamming the provider
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKeysMap = ref.watch(apiKeysProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Model Analyzer',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: GlassmorphismTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pantau limit dan sisa kuota spesifik untuk setiap model AI',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: GlassmorphismTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: GlassmorphismTheme.primaryRed),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (apiKeysMap.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.vpn_key_off_rounded, size: 64, color: GlassmorphismTheme.textSecondary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada API Key yang diinput',
                    style: GoogleFonts.inter(fontSize: 16, color: GlassmorphismTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...apiKeysMap.entries.map((entry) {
              final provider = entry.key;
              final keys = entry.value;
              final icon = ApiKeyModel.providerIcons[provider] ?? '•';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          icon,
                          style: const TextStyle(fontSize: 20, color: GlassmorphismTheme.primaryRed),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          provider,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 1;
                      if (constraints.maxWidth > 1100) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth > 750) {
                        crossAxisCount = 2;
                      }

                      return MasonryGridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        itemCount: keys.length,
                        itemBuilder: (context, i) {
                          final keyData = keys[i];
                          final name = keyData['name'] ?? 'Key ${i + 1}';
                          final apiKey = keyData['key'] ?? '';
                          final id = '$provider-$name-$apiKey';
                          
                          final loading = _isLoading[id] ?? false;
                          final models = _modelData[id] ?? [];

                          return GlassCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(20),
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _maskKey(apiKey),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      color: GlassmorphismTheme.textSecondary.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (models.isEmpty && !loading)
                                TextButton.icon(
                                  onPressed: () => _refreshUsage(provider, name, apiKey),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Tampilkan Model', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: GlassmorphismTheme.primaryRed),
                                )
                              else if (loading)
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              else
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _checkAllModels(provider, apiKey, id),
                                      icon: const Icon(Icons.bolt_rounded, size: 16),
                                      label: const Text('Ping Semua', style: TextStyle(fontSize: 11)),
                                      style: TextButton.styleFrom(foregroundColor: GlassmorphismTheme.primaryRed),
                                    ),
                                    IconButton(
                                      onPressed: () => _refreshUsage(provider, name, apiKey),
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      tooltip: 'Refresh Model List',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          
                          if (models.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 24, thickness: 0.5),
                            ...models.map((modelId) {
                              final modelUsage = _modelUsageData[id]?[modelId];
                              final modelLoad = _modelLoading[id]?[modelId] ?? false;
                              
                              final double usagePercent = modelUsage != null 
                                  ? modelUsage.tokenUsagePercent 
                                  : 0.0;
                              final bool isLow = usagePercent > 0.8;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            modelId,
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: GlassmorphismTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (modelLoad)
                                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                                        else if (modelUsage == null)
                                          GestureDetector(
                                            onTap: () => _checkModelSpecific(provider, apiKey, modelId, id),
                                            child: Icon(Icons.play_circle_outline_rounded, size: 18, color: GlassmorphismTheme.primaryRed.withOpacity(0.6)),
                                          )
                                        else
                                          _StatusBadge(isLow: isLow, error: modelUsage.error),
                                      ],
                                    ),
                                    if (modelUsage != null) ...[
                                      const SizedBox(height: 12),
                                      // Detailed Stats Table-like UI
                                      _buildStatRow('Request ID', modelUsage.requestId),
                                      _buildStatRow('Status', modelUsage.message, color: modelUsage.isActive ? GlassmorphismTheme.success : GlassmorphismTheme.error),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(child: _buildTokenStat('Input', modelUsage.inputTokens)),
                                          Expanded(child: _buildTokenStat('Output', modelUsage.outputTokens)),
                                          Expanded(child: _buildTokenStat('Total', modelUsage.totalTokens)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Usage bar for rate limit (if available)
                                      if (modelUsage.limitTokens > 0) ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Quota Remaining',
                                              style: GoogleFonts.inter(fontSize: 10, color: GlassmorphismTheme.textSecondary),
                                            ),
                                            Text(
                                              _formatNumber(modelUsage.remainingTokens),
                                              style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Stack(
                                          children: [
                                            Container(
                                              height: 4,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: GlassmorphismTheme.primaryRed.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: usagePercent.clamp(0.0, 1.0),
                                              child: Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: GlassmorphismTheme.primaryRed,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length < 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: GlassmorphismTheme.textSecondary)),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color ?? GlassmorphismTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: GlassmorphismTheme.textSecondary)),
        Text(
          _formatNumber(value),
          style: GoogleFonts.robotoMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: GlassmorphismTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isLow;
  final String? error;
  const _StatusBadge({required this.isLow, this.error});

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null && !error!.contains('Status 200');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasError
            ? GlassmorphismTheme.error.withOpacity(0.1)
            : (isLow 
                ? GlassmorphismTheme.primaryRed.withOpacity(0.1)
                : GlassmorphismTheme.success.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasError
              ? GlassmorphismTheme.error.withOpacity(0.2)
              : (isLow 
                  ? GlassmorphismTheme.primaryRed.withOpacity(0.2)
                  : GlassmorphismTheme.success.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasError 
                  ? GlassmorphismTheme.error 
                  : (isLow ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.success),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hasError ? (error!.length > 15 ? error!.substring(0, 15) : error!) : (isLow ? 'Limit Menipis' : 'Aktif'),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasError 
                  ? GlassmorphismTheme.error 
                  : (isLow ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.success),
            ),
          ),
        ],
      ),
    );
  }
}
