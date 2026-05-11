import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../models/api_key_model.dart';
import '../providers/api_keys_provider.dart';

class ApiKeysPage extends ConsumerStatefulWidget {
  const ApiKeysPage({super.key});

  @override
  ConsumerState<ApiKeysPage> createState() => _ApiKeysPageState();
}

class _ApiKeysPageState extends ConsumerState<ApiKeysPage> with TickerProviderStateMixin {
  final Map<String, TextEditingController> _newNameControllers = {};
  final Map<String, TextEditingController> _newKeyControllers = {};
  final Map<String, bool> _obscured = {};
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    for (final provider in ApiKeyModel.supportedProviders) {
      _newNameControllers[provider] = TextEditingController();
      _newKeyControllers[provider] = TextEditingController();
      _obscured[provider] = true;
    }
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    for (final c in _newNameControllers.values) c.dispose();
    for (final c in _newKeyControllers.values) c.dispose();
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKeys = ref.watch(apiKeysProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          // ── Background Blobs ──
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (40 * _blobController.value),
                    right: -120 + (60 * _blobController.value),
                    child: _buildBlob(450, Colors.blue.withOpacity(0.04)),
                  ),
                  Positioned(
                    bottom: 50 - (30 * _blobController.value),
                    left: -100 + (50 * _blobController.value),
                    child: _buildBlob(400, GlassmorphismTheme.primaryRed.withOpacity(0.05)),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ──
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final provider = ApiKeyModel.supportedProviders[index];
                        return _buildProviderCard(provider, apiKeys[provider] ?? []);
                      },
                      childCount: ApiKeyModel.supportedProviders.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'API Management',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GlassmorphismTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text('Rotation', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola banyak API key untuk rotasi otomatis.',
              style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(String provider, List<Map<String, String>> keys) {
    final icon = ApiKeyModel.providerIcons[provider] ?? '●';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Text(provider, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
              const Spacer(),
              Text('${keys.length} Keys', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          
          if (keys.isNotEmpty) ...[
            ...keys.asMap().entries.map((entry) => _buildKeyItem(provider, entry.key, entry.value)),
            const SizedBox(height: 12),
          ],

          _buildAddKeySection(provider),
        ],
      ),
    );
  }

  Widget _buildKeyItem(String provider, int index, Map<String, String> keyData) {
    final name = keyData['name'] ?? 'Key';
    final key = keyData['key'] ?? '';
    final isObscured = _obscured[provider]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: GlassmorphismTheme.primaryRed.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.key_rounded, size: 14, color: GlassmorphismTheme.primaryRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
                Text(
                  isObscured ? '••••••••••••••••${key.length > 4 ? key.substring(key.length - 4) : ""}' : key,
                  style: GoogleFonts.robotoMono(fontSize: 10, color: GlassmorphismTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(apiKeysProvider.notifier).deleteKey(provider, index),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAddKeySection(String provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _newNameControllers[provider],
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nama (misal: "Personal")',
              isDense: true,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newKeyControllers[provider],
                  obscureText: _obscured[provider]!,
                  style: GoogleFonts.robotoMono(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'API Key',
                    isDense: true,
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscured[provider]! ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _obscured[provider] = !_obscured[provider]!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: GlassmorphismTheme.primaryRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: GlassmorphismTheme.redGlowShadow,
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
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
