import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/rag_service_provider.dart';
import '../providers/research_blueprint_provider.dart';

class RagExplorerPage extends ConsumerStatefulWidget {
  const RagExplorerPage({super.key});

  @override
  ConsumerState<RagExplorerPage> createState() => _RagExplorerPageState();
}

class _RagExplorerPageState extends ConsumerState<RagExplorerPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allResults = [];
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _llmResponse = '';

  // Filter state
  String? _selectedBab;        // null = Semua
  String? _selectedSubBab;     // null = semua sub-bab dalam bab
  String? _expandedBab;        // which bab chip is currently expanded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  List<dynamic> _applyFilter(List<dynamic> results) {
    if (_selectedBab == null) return results;
    return results.where((chunk) {
      final subBab = (chunk['sub_bab'] ?? '').toString().toLowerCase();
      final selectedBabLower = _selectedBab!.toLowerCase();
      if (_selectedSubBab != null) {
        return subBab.contains(_selectedSubBab!.toLowerCase());
      }
      return subBab.contains(selectedBabLower);
    }).toList();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = true;
      _allResults = [];
      _searchResults = [];
    });

    try {
      // Siapkan filter metadata jika ada bab/sub-bab yang dipilih
      String filterParam = "";
      if (_selectedSubBab != null) {
        filterParam = "&filter_key=sub_bab&filter_val=${Uri.encodeComponent(_selectedSubBab!)}";
      } else if (_selectedBab != null) {
        filterParam = "&filter_key=sub_bab&filter_val=${Uri.encodeComponent(_selectedBab!)}";
      }

      final url = 'http://localhost:28146/search?q=${Uri.encodeComponent(query)}&top_k=10$filterParam';
      final res = await http.get(Uri.parse(url));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        final all = data['results'] ?? [];
        setState(() {
          _allResults = all;
          _searchResults = all; // Sekarang server sudah memfilter, jadi kita pakai semua hasil dari server
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _llmResponse = '❌ Error RAG Search: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _setFilter({String? bab, String? subBab}) {
    setState(() {
      _selectedBab = bab;
      _selectedSubBab = subBab;
    });
    _performSearch(); // Langsung cari ulang ke server dengan filter baru
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Data RAG?'),
        content: const Text(
            'Ini akan mengosongkan ChromaDB. Semua dokumen yang sudah di-index akan hilang dari semantic search sampai Anda mereprosesnya lagi. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res =
          await http.delete(Uri.parse('http://localhost:28146/documents/all'));
      if (res.statusCode == 200) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Semua data RAG berhasil dihapus')));
        setState(() => _searchResults.clear());
        ref.read(ragStateProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteChunk(String chunkId) async {
    try {
      final res = await http.delete(Uri.parse(
          'http://localhost:28146/chunks/${Uri.encodeComponent(chunkId)}'));
      if (res.statusCode == 200) {
        setState(() {
          _searchResults.removeWhere((c) => c['id'] == chunkId);
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chunk berhasil dihapus')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> chunk) async {
    final subBabController =
        TextEditingController(text: chunk['sub_bab']?.toString() ?? '');
    final variabelController = TextEditingController(
        text: chunk['kategori_variabel']?.toString() ?? '');
    final sitasiController =
        TextEditingController(text: chunk['sitasi']?.toString() ?? '');
    final halamanController =
        TextEditingController(text: chunk['halaman']?.toString() ?? '');
    final daftarPustakaController = TextEditingController(
        text: chunk['daftar_pustaka_source']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
            const SizedBox(width: 10),
            const Text('Edit Metadata Manual'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(
                    subBabController, 'Sub-Bab', Icons.bookmark_outline),
                _buildEditField(variabelController, 'Kategori Variabel',
                    Icons.layers_outlined),
                _buildEditField(sitasiController, 'Sitasi (APA 7)',
                    Icons.psychology_outlined),
                _buildEditField(
                    halamanController, 'Halaman', Icons.menu_book_rounded),
                _buildEditField(daftarPustakaController,
                    'Daftar Pustaka Source', Icons.list_alt_rounded,
                    maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final res = await http.post(
          Uri.parse('http://localhost:28146/chunks/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chunk_id': chunk['id'],
            'metadata': {
              'sub_bab': subBabController.text.trim(),
              'kategori_variabel': variabelController.text.trim(),
              'sitasi': sitasiController.text.trim(),
              'halaman': halamanController.text.trim(),
              'daftar_pustaka_source': daftarPustakaController.text.trim(),
            }
          }),
        );

        if (res.statusCode == 200) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Berhasil memperbarui metadata')));
          _performSearch(); // Refresh data
        } else {
          throw 'Server Error: ${res.body}';
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Gagal update: $e')));
      }
    }
  }

  Widget _buildFilterCard() {
    final blueprint = ref.watch(researchBlueprintProvider);
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: GlassmorphismTheme.primaryRed),
              const SizedBox(width: 10),
              Text('Filter Struktur Skripsi',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GlassmorphismTheme.textPrimary)),
              const Spacer(),
              if (_selectedBab != null)
                TextButton(
                  onPressed: () => _setFilter(bab: null, subBab: null),
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: GlassmorphismTheme.primaryRed)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Chip "Semua"
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Semua Data'),
                    selected: _selectedBab == null,
                    onSelected: (val) => _setFilter(bab: null, subBab: null),
                    selectedColor: GlassmorphismTheme.primaryRed.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _selectedBab == null ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: _selectedBab == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                // Chips per Bab
                ...blueprint.structure.map((bab) {
                  final isSelected = _selectedBab == bab.babLabel;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(bab.babLabel),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          _setFilter(bab: bab.babLabel, subBab: null);
                        } else {
                          _setFilter(bab: null, subBab: null);
                        }
                      },
                      selectedColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          // Sub-bab section (hanya muncul jika bab dipilih)
          if (_selectedBab != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Colors.white10),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...blueprint.structure
                      .firstWhere((b) => b.babLabel == _selectedBab)
                      .subChapters
                      .where((s) => !s.startsWith('  ')) // Ambil sub-bab utama saja
                      .map((sub) {
                    final isSubSelected = _selectedSubBab == sub;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(sub, style: const TextStyle(fontSize: 11)),
                        selected: isSubSelected,
                        onSelected: (val) {
                          _setFilter(bab: _selectedBab, subBab: val ? sub : null);
                        },
                        backgroundColor: Colors.white.withOpacity(0.05),
                        selectedColor: Colors.blueAccent.withOpacity(0.2),
                        checkmarkColor: Colors.blueAccent,
                        labelStyle: TextStyle(
                          color: isSubSelected ? Colors.blueAccent : GlassmorphismTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ragState = ref.watch(ragStateProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RAG Explorer',
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: GlassmorphismTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                      'Cari dan lihat potongan dokumen dari Vector Database ChromaDB.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: GlassmorphismTheme.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: ragState.isActive ? _deleteAll : null,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Clear All RAG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilterCard(),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            color: GlassmorphismTheme.textPrimary,
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cari di seluruh dokumen...',
                          hintStyle: TextStyle(
                              color: GlassmorphismTheme.textSecondary),
                          prefixIcon: Icon(Icons.search,
                              color: GlassmorphismTheme.textSecondary),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.03),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSearching || !ragState.isActive
                          ? null
                          : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassmorphismTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Search Vector'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 1;
                  if (constraints.maxWidth > 1200) {
                    crossAxisCount = 3;
                  } else if (constraints.maxWidth > 800) {
                    crossAxisCount = 2;
                  }

                  return MasonryGridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final chunk = _searchResults[i];
                      final isStructured = chunk['is_structured'] == 'true' ||
                          chunk.containsKey('sub_bab');
                      final delay = Duration(milliseconds: i * 100);

                      if (isStructured) {
                        return GlassCard(
                          margin: EdgeInsets.zero,
                          padding: EdgeInsets.zero,
                          entranceDelay: delay,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Section
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          _buildStatusBadge(
                                            label:
                                                chunk['sub_bab']?.toString() ??
                                                    'Umum',
                                            color:
                                                GlassmorphismTheme.primaryRed,
                                            icon:
                                                Icons.bookmark_outline_rounded,
                                          ),
                                          if (chunk['kategori_variabel'] !=
                                              null)
                                            _buildStatusBadge(
                                              label: chunk['kategori_variabel']
                                                  .toString(),
                                              color: Colors.blueAccent,
                                              icon: Icons.layers_outlined,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.menu_book_rounded,
                                            size: 14,
                                            color: GlassmorphismTheme
                                                .textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                            'Hal: ${chunk["halaman"] ?? chunk["page"] ?? "?"}',
                                            style: GoogleFonts.inter(
                                                color: GlassmorphismTheme
                                                    .textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Colors.blueAccent,
                                              size: 18),
                                          onPressed: () =>
                                              _showEditDialog(chunk),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: GlassmorphismTheme.error
                                                  .withOpacity(0.6),
                                              size: 18),
                                          onPressed: () =>
                                              _deleteChunk(chunk['id']),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Content Section
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      chunk['content'] ??
                                          chunk['kutipan_verbatim'] ??
                                          '',
                                      style: GoogleFonts.inter(
                                        color: GlassmorphismTheme.textPrimary,
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Citation Box
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blueAccent.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.blueAccent
                                                .withOpacity(0.1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.psychology_outlined,
                                                  size: 16,
                                                  color: Colors.blueAccent),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  chunk['sitasi']?.toString() ??
                                                      'Tanpa Sitasi',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.blueAccent,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (chunk['daftar_pustaka_source'] !=
                                                  null &&
                                              chunk['daftar_pustaka_source'] !=
                                                  '-') ...[
                                            const SizedBox(height: 8),
                                            const Divider(
                                                height: 1,
                                                color: Colors.white10),
                                            const SizedBox(height: 8),
                                            Text(
                                              chunk['daftar_pustaka_source'],
                                              style: GoogleFonts.inter(
                                                color: GlassmorphismTheme
                                                    .textSecondary,
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GlassCard(
                        margin: EdgeInsets.zero,
                        entranceDelay: delay,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      'Chunk ${chunk["chunk_index"]} (Hal ${chunk["halaman"] ?? chunk["page_start"] ?? "?"})',
                                      style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: GlassmorphismTheme.error,
                                      size: 18),
                                  onPressed: () => _deleteChunk(chunk['id']),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(chunk["content"] ?? '',
                                style: TextStyle(
                                    color: GlassmorphismTheme.textPrimary,
                                    fontSize: 12,
                                    height: 1.5)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      {required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
