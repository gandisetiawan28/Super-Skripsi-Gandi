import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ── Undo/Redo Action Classes ──────────────────────────────────────────────────

abstract class RagAction {
  String get description;
  Future<void> undo(BuildContext context, WidgetRef ref);
  Future<void> redo(BuildContext context, WidgetRef ref);
}

class DeleteChunkAction extends RagAction {
  final Map<String, dynamic> chunk;
  final VoidCallback onRefresh;

  DeleteChunkAction(this.chunk, {required this.onRefresh});

  @override
  String get description => "Hapus Potongan Data";

  @override
  Future<void> undo(BuildContext context, WidgetRef ref) async {
    // Optimistic UI: Kembalikan ke list lokal dulu
    final state = (context.findAncestorStateOfType<_RagExplorerPageState>());
    state?._addChunkLocally(chunk);

    final resp = await http.post(
      Uri.parse('http://localhost:28146/add_manual'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doc_id': chunk['doc_id'],
        'content': chunk['content'] ?? chunk['kutipan_verbatim'],
        'metadata': chunk,
      }),
    );
    
    if (resp.statusCode == 200) {
      // Tunggu sebentar agar ChromaDB selesai indexing sebelum refresh
      await Future.delayed(const Duration(milliseconds: 500));
      onRefresh();
    }
  }

  @override
  Future<void> redo(BuildContext context, WidgetRef ref) async {
    await http.delete(Uri.parse('http://localhost:28146/chunks/${Uri.encodeComponent(chunk['id'])}'));
    onRefresh();
  }
}

class EditMetadataAction extends RagAction {
  final String chunkId;
  final Map<String, String> oldMeta;
  final Map<String, String> newMeta;
  final VoidCallback onRefresh;

  EditMetadataAction({
    required this.chunkId,
    required this.oldMeta,
    required this.newMeta,
    required this.onRefresh,
  });

  @override
  String get description => "Edit Metadata";

  @override
  Future<void> undo(BuildContext context, WidgetRef ref) async => _update(oldMeta);
  @override
  Future<void> redo(BuildContext context, WidgetRef ref) async => _update(newMeta);

  Future<void> _update(Map<String, String> meta) async {
    await http.post(
      Uri.parse('http://localhost:28146/chunks/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chunk_id': chunkId, 'metadata': meta}),
    );
    onRefresh();
  }
}

class ClearAllAction extends RagAction {
  final List<dynamic> savedChunks;
  final VoidCallback onRefresh;

  ClearAllAction(this.savedChunks, {required this.onRefresh});

  @override
  String get description => "Hapus Semua Data";

  @override
  Future<void> undo(BuildContext context, WidgetRef ref) async {
    final state = (context.findAncestorStateOfType<_RagExplorerPageState>());
    for (var chunk in savedChunks) {
      state?._addChunkLocally(chunk);
    }

    // Restore one by one
    for (var chunk in savedChunks) {
      await http.post(
        Uri.parse('http://localhost:28146/add_manual'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doc_id': chunk['doc_id'],
          'content': chunk['content'] ?? chunk['kutipan_verbatim'],
          'metadata': chunk,
        }),
      );
    }
    // Tunggu lebih lama untuk batch restore
    await Future.delayed(const Duration(milliseconds: 1000));
    onRefresh();
  }

  @override
  Future<void> redo(BuildContext context, WidgetRef ref) async {
    await http.delete(Uri.parse('http://localhost:28146/documents/all'));
    onRefresh();
  }
}

class _RagExplorerPageState extends ConsumerState<RagExplorerPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allResults = [];
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _llmResponse = '';

  // Filter state
  String? _selectedBab;        // null = Semua
  Set<String> _selectedSubBabs = {}; // multiple sub-bab selection
  Timer? _debounceTimer; // Debounce for search requests
  String? _expandedBab;        // which bab chip is currently expanded
  bool _showSubBabDetails = true; // Toggle to collapse/expand sub-chapter list
  
  final List<RagAction> _undoStack = [];
  final List<RagAction> _redoStack = [];
  bool _isProcessingUndoRedo = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch(immediate: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addChunkLocally(dynamic chunk) {
    setState(() {
      if (!_allResults.any((c) => c['id'] == chunk['id'])) {
        _allResults.insert(0, chunk);
        _searchResults = _applyFilter(_allResults);
      }
    });
  }

  void _pushAction(RagAction action) {
    setState(() {
      _undoStack.add(action);
      _redoStack.clear();
      if (_undoStack.length > 30) _undoStack.removeAt(0);
    });
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || _isProcessingUndoRedo) return;
    final action = _undoStack.removeLast();
    setState(() => _isProcessingUndoRedo = true);
    try {
      await action.undo(context, ref);
      setState(() => _redoStack.add(action));
      _showUndoRedoSnackBar("Membatalkan: ${action.description}", isUndo: true);
    } catch (e) {
      _showUndoRedoSnackBar("Gagal membatalkan: $e", isUndo: true);
    } finally {
      setState(() => _isProcessingUndoRedo = false);
    }
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty || _isProcessingUndoRedo) return;
    final action = _redoStack.removeLast();
    setState(() => _isProcessingUndoRedo = true);
    try {
      await action.redo(context, ref);
      setState(() => _undoStack.add(action));
      _showUndoRedoSnackBar("Mengulangi: ${action.description}", isUndo: false);
    } catch (e) {
      _showUndoRedoSnackBar("Gagal mengulangi: $e", isUndo: false);
    } finally {
      setState(() => _isProcessingUndoRedo = false);
    }
  }

  void _showUndoRedoSnackBar(String message, {bool isUndo = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isUndo ? Icons.undo_rounded : Icons.redo_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  List<dynamic> _applyFilter(List<dynamic> results) {
    if (_selectedBab == null) return results;
    return results.where((chunk) {
      final subBab = (chunk['sub_bab'] ?? '').toString().toLowerCase();
      final selectedBabLower = _selectedBab!.toLowerCase();
      if (_selectedSubBabs.isNotEmpty) {
        return _selectedSubBabs.any((s) => subBab.contains(s.toLowerCase()));
      }
      return subBab.contains(selectedBabLower);
    }).toList();
  }

  Future<void> _performSearch({bool immediate = false}) async {
    if (immediate) {
      _debounceTimer?.cancel();
      await _executeSearch();
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _executeSearch();
      });
    }
  }

  Future<void> _executeSearch() async {
    final ragState = ref.read(ragStateProvider);
    if (!ragState.isActive) return;

    setState(() {
      _isSearching = true;
      _allResults = [];
      _searchResults = [];
    });

    try {
      // Siapkan filter metadata jika ada bab/sub-bab yang dipilih
      String filterParam = "";
      if (_selectedSubBabs.isNotEmpty) {
        final vals = _selectedSubBabs.join("|");
        filterParam = "&sub_bab=${Uri.encodeComponent(vals)}";
      } else if (_selectedBab != null) {
        filterParam = "&bab=${Uri.encodeComponent(_selectedBab!)}";
      }

      final query = _searchController.text;
      final url = 'http://localhost:28146/search?q=${Uri.encodeComponent(query)}&top_k=20$filterParam';
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

  void _setFilter({String? bab, Set<String>? subBabs}) {
    setState(() {
      _selectedBab = bab;
      _selectedSubBabs = subBabs ?? {};
      if (bab != null) _showSubBabDetails = true; // Auto expand saat pilih bab
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

    // Ambil backup data sebelum dihapus (untuk Undo)
    final savedBackup = List.from(_allResults);

    try {
      final res =
          await http.delete(Uri.parse('http://localhost:28146/documents/all'));
      if (res.statusCode == 200) {
        // Daftarkan ke stack undo
        _pushAction(ClearAllAction(savedBackup, onRefresh: _performSearch));

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

  Future<void> _deleteChunk(Map<String, dynamic> chunk) async {
    try {
      final res = await http.delete(Uri.parse(
          'http://localhost:28146/chunks/${Uri.encodeComponent(chunk['id'])}'));
      if (res.statusCode == 200) {
        _pushAction(DeleteChunkAction(chunk, onRefresh: _performSearch));
        
        setState(() {
          _searchResults.removeWhere((c) => c['id'] == chunk['id']);
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
      final Map<String, String> oldMeta = {
        'sub_bab': chunk['sub_bab']?.toString() ?? '',
        'kategori_variabel': chunk['kategori_variabel']?.toString() ?? '',
        'sitasi': chunk['sitasi']?.toString() ?? '',
        'halaman': chunk['halaman']?.toString() ?? '',
        'daftar_pustaka_source': chunk['daftar_pustaka_source']?.toString() ?? '',
      };
      
      final Map<String, String> newMeta = {
        'sub_bab': subBabController.text.trim(),
        'kategori_variabel': variabelController.text.trim(),
        'sitasi': sitasiController.text.trim(),
        'halaman': halamanController.text.trim(),
        'daftar_pustaka_source': daftarPustakaController.text.trim(),
      };

      try {
        final res = await http.post(
          Uri.parse('http://localhost:28146/chunks/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chunk_id': chunk['id'],
            'metadata': newMeta
          }),
        );

        if (res.statusCode == 200) {
          _pushAction(EditMetadataAction(
            chunkId: chunk['id'],
            oldMeta: oldMeta,
            newMeta: newMeta,
            onRefresh: _performSearch,
          ));

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
    if (blueprint.structure.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, size: 18, color: GlassmorphismTheme.primaryRed),
              const SizedBox(width: 10),
              Text('Filter Struktur Skripsi',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: GlassmorphismTheme.textPrimary)),
              const Spacer(),
              // Toggle Expand/Collapse Sub-Chapters
              if (_selectedBab != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showSubBabDetails = !_showSubBabDetails),
                    icon: Icon(_showSubBabDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: Colors.blueAccent),
                    label: Text(_showSubBabDetails ? 'Sembunyikan Detail' : 'Tampilkan Detail', 
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.blueAccent)),
                  ),
                ),
              if (_selectedBab != null || _selectedSubBabs.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _setFilter(bab: null, subBabs: {});
                  },
                  child: Text('Reset Filter', style: GoogleFonts.inter(fontSize: 12, color: GlassmorphismTheme.primaryRed)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row for BAB Selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Semua Bab',
                  isSelected: _selectedBab == null,
                  onTap: () => _setFilter(bab: null, subBabs: {}),
                ),
                ...blueprint.structure.map((bab) => _buildFilterChip(
                  label: bab.babLabel,
                  isSelected: _selectedBab == bab.babLabel,
                  onTap: () => _setFilter(bab: bab.babLabel, subBabs: {}),
                )),
              ],
            ),
          ),

          // Sub-Chapters (Multi-select) with Animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _selectedBab != null && _showSubBabDetails ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Colors.white10),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Tombol Pilih Semua
                    _buildSubChapterChip(
                      label: "Pilih Semua",
                      isSelected: _selectedSubBabs.length == blueprint.structure
                          .firstWhere((b) => b.babLabel == _selectedBab)
                          .subChapters.length,
                      onTap: () {
                        final currentSubBabs = blueprint.structure
                            .firstWhere((b) => b.babLabel == _selectedBab)
                            .subChapters;
                        
                        if (_selectedSubBabs.length == currentSubBabs.length) {
                          _setFilter(bab: _selectedBab, subBabs: {});
                        } else {
                          _setFilter(bab: _selectedBab, subBabs: currentSubBabs.toSet());
                        }
                      },
                    ),
                    ...blueprint.structure
                        .firstWhere((b) => b.babLabel == _selectedBab)
                        .subChapters
                        .map((sub) {
                        final isSelected = _selectedSubBabs.contains(sub);
                        return _buildSubChapterChip(
                          label: sub,
                          isSelected: isSelected,
                          onTap: () {
                            final newSubBabs = Set<String>.from(_selectedSubBabs);
                            if (isSelected) {
                              newSubBabs.remove(sub);
                            } else {
                              newSubBabs.add(sub);
                            }
                            _setFilter(bab: _selectedBab, subBabs: newSubBabs);
                          },
                        );
                      }).toList(),
                  ],
                ),
              ],
            ) : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return _HoverableChip(
      isSelected: isSelected,
      onTap: onTap,
      label: label,
      activeColor: GlassmorphismTheme.primaryRed,
      fontSize: 12,
      borderRadius: 12,
      margin: const EdgeInsets.only(right: 12),
    );
  }

  Widget _buildSubChapterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    // Determine level by indentation (space)
    final level = (label.length - label.trimLeft().length) ~/ 2;
    final cleanLabel = label.trim();

    return _HoverableChip(
      isSelected: isSelected,
      onTap: onTap,
      label: cleanLabel,
      activeColor: GlassmorphismTheme.primaryRed,
      fontSize: 11 - (level * 0.5),
      borderRadius: 8,
      showCheck: true,
      level: level,
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
  Widget _buildUndoRedoButton({required IconData icon, required VoidCallback? onPressed, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: onPressed == null ? Colors.white24 : Colors.white70),
        padding: const EdgeInsets.all(10),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ragState = ref.watch(ragStateProvider);

    // Auto-refresh saat servis RAG menjadi aktif (untuk data awal)
    ref.listen<RagState>(ragStateProvider, (previous, next) {
      if ((previous == null || !previous.isActive) && next.isActive) {
        _performSearch(immediate: true);
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _redo,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        child: SingleChildScrollView(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    onPressed: _undoStack.isEmpty || _isProcessingUndoRedo ? null : _undo,
                    color: _undoStack.isEmpty || _isProcessingUndoRedo ? Colors.white24 : Colors.white,
                    tooltip: 'Undo (Ctrl+Z)',
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.redo_rounded,
                    label: 'Redo',
                    onPressed: _redoStack.isEmpty || _isProcessingUndoRedo ? null : _redo,
                    color: _redoStack.isEmpty || _isProcessingUndoRedo ? Colors.white24 : Colors.white,
                    tooltip: 'Redo (Ctrl+Y)',
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: ragState.isActive ? _deleteAll : null,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Clear All RAG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassmorphismTheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
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
                        onChanged: (_) => _performSearch(),
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
          
          // Statistik Jumlah Data
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, size: 16, color: GlassmorphismTheme.textSecondary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'Ditemukan ${_searchResults.length} data',
                  style: GoogleFonts.inter(
                    color: GlassmorphismTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ragState.status == RagStatus.ready) ...[
                  Text(
                    ' dari total seluruh data di database',
                    style: GoogleFonts.inter(
                      color: GlassmorphismTheme.textSecondary.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
                const Spacer(),
                if (_isSearching)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: GlassmorphismTheme.primaryRed),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (_isSearching && _searchResults.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
                  const SizedBox(height: 16),
                  Text('Mencari data...', style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary)),
                ],
              ),
            )
          else if (!ragState.isActive)
             Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(ragState.statusLabel, style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(ragState.tooltipLabel, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            )
          else if (_searchResults.isEmpty && !_isSearching)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('Tidak ada data ditemukan', style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Pastikan Anda sudah mengunggah dan mengindeks dokumen.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                ],
              ),
            )
          else
            LayoutBuilder(
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
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                                              _deleteChunk(chunk),
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
                                  onPressed: () => _deleteChunk(chunk),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: onPressed == null ? Colors.transparent : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: onPressed == null ? Colors.white.withOpacity(0.05) : color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
      {required String label, required Color color, required IconData icon}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300), // Prevent badge from being too wide
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
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

class _HoverableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final double fontSize;
  final double borderRadius;
  final bool showCheck;
  final int level;
  final EdgeInsetsGeometry? margin;

  const _HoverableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.fontSize,
    required this.borderRadius,
    this.showCheck = false,
    this.level = 0,
    this.margin,
  });

  @override
  State<_HoverableChip> createState() => _HoverableChipState();
}

class _HoverableChipState extends State<_HoverableChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? widget.activeColor 
                : (_isHovered ? widget.activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.isSelected 
                  ? widget.activeColor 
                  : (_isHovered ? widget.activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.1)),
            ),
            boxShadow: widget.isSelected && _isHovered
                ? [BoxShadow(color: widget.activeColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCheck && widget.isSelected) ...[
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: widget.fontSize,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? Colors.white : (_isHovered ? widget.activeColor : GlassmorphismTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
