import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../models/api_key_model.dart';
import '../providers/api_keys_provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> {
  final Map<String, TextEditingController> _newNameControllers = {};
  final Map<String, TextEditingController> _newKeyControllers = {};
  final Map<String, bool> _obscured = {};

  @override
  void initState() {
    super.initState();
    for (final provider in ApiKeyModel.supportedProviders) {
      _newNameControllers[provider] = TextEditingController();
      _newKeyControllers[provider] = TextEditingController();
      _obscured[provider] = true;
    }
  }

  @override
  void dispose() {
    for (final c in _newNameControllers.values) c.dispose();
    for (final c in _newKeyControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKeys = ref.watch(apiKeysProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'API Management',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Rotation Active',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Beri nama dan kelola banyak API key untuk rotasi otomatis.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: GlassmorphismTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;
              if (constraints.maxWidth > 1100) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 750) {
                crossAxisCount = 2;
              }

              final providers = ApiKeyModel.supportedProviders;

              return MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                itemCount: providers.length,
                itemBuilder: (context, i) {
                  final provider = providers[i];
                  final icon = ApiKeyModel.providerIcons[provider] ?? '●';
                  final keys = apiKeys[provider] ?? [];

                  return GlassCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Text(
                              provider,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${keys.length} Keys',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: GlassmorphismTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        
                        // Key List
                        if (keys.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Belum ada API key tersimpan.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: GlassmorphismTheme.textSecondary,
                              ),
                            ),
                          )
                        else
                          ...keys.asMap().entries.map((entry) {
                            final index = entry.key;
                            final keyObj = entry.value;
                            final name = keyObj['name'] ?? 'Key';
                            final key = keyObj['key'] ?? '';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: GlassmorphismTheme.textPrimary.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.vpn_key_rounded, size: 16, color: GlassmorphismTheme.primaryRed.withOpacity(0.6)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: GlassmorphismTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _obscured[provider]! 
                                            ? '••••••••••••••••${key.length > 4 ? key.substring(key.length - 4) : ""}'
                                            : key,
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 11,
                                            color: GlassmorphismTheme.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                                    onPressed: () => ref.read(apiKeysProvider.notifier).deleteKey(provider, index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          }),
                        
                        const SizedBox(height: 20),
                        
                        // Add Key Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: GlassmorphismTheme.primaryRed.withOpacity(0.1), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Key Baru',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GlassmorphismTheme.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newNameControllers[provider],
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Misal: "Personal"',
                                  labelText: 'Nama / Label',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newKeyControllers[provider],
                                      obscureText: _obscured[provider]!,
                                      style: GoogleFonts.robotoMono(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'sk-...',
                                        labelText: 'API Key',
                                        labelStyle: const TextStyle(fontSize: 12),
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscured[provider]!
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() => _obscured[provider] = !_obscured[provider]!),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: GlassmorphismTheme.primaryRed,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: GlassmorphismTheme.primaryRed.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        final name = _newNameControllers[provider]!.text.trim();
                                        final key = _newKeyControllers[provider]!.text.trim();
                                        if (key.isNotEmpty) {
                                          ref.read(apiKeysProvider.notifier).saveKey(provider, name, key);
                                          _newNameControllers[provider]!.clear();
                                          _newKeyControllers[provider]!.clear();
                                        }
                                      },
                                      icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
