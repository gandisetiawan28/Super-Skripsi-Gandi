import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import '../models/latihan_model.dart';
import '../prompts/latihan_prompt.dart';
import 'ai_extraction_service.dart';
import 'api_key_service.dart';
import 'pdf_service.dart';

import '../utils/session_utils.dart';

class LatihanService {
  final ApiKeyService _apiKeyService;
  late final AiExtractionService _aiService;
  final PdfService _pdfService = PdfService();
  final String? _userEmail;

  static const String _hiveBoxBaseName = 'latihan_cache';
  static const String _historyBoxBaseName = 'latihan_history';
  static const String _settingsBoxName = 'latihan_settings';
  static const String _analysisBoxName = 'latihan_analysis';

  LatihanService(this._userEmail) : _apiKeyService = ApiKeyService(_userEmail) {
    _aiService = AiExtractionService(_apiKeyService);
  }

  // ─── HISTORY ─────────────────────────────────────────────────────────────

  Future<List<LatihanHistoryItem>> loadHistory() async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_historyBoxBaseName, _userEmail));
      final raw = box.get('items');
      if (raw == null) return [];
      final list = jsonDecode(raw as String) as List;
      return list
          .map((e) => LatihanHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print('Load History Error: $e');
      return [];
    }
  }

  Future<void> saveHistory(LatihanHistoryItem item) async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_historyBoxBaseName, _userEmail));
      final current = await loadHistory();
      final updated = [item, ...current].take(50).toList();
      final jsonStr = jsonEncode(updated.map((e) => e.toJson()).toList());
      await box.put('items', jsonStr);
    } catch (e) {
      print('Save History Error: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_historyBoxBaseName, _userEmail));
      await box.clear();
    } catch (_) {}
  }

  Future<void> deleteSingleHistory(String id) async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_historyBoxBaseName, _userEmail));
      final current = await loadHistory();
      final updated = current.where((item) => item.id != id).toList();
      final jsonStr = jsonEncode(updated.map((e) => e.toJson()).toList());
      await box.put('items', jsonStr);
    } catch (e) {
      print('Delete History Error: $e');
    }
  }

  // ─── SETTINGS ────────────────────────────────────────────────────────────

  Future<LatihanSettings?> loadSettings() async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_settingsBoxName, _userEmail));
      final raw = box.get('current');
      if (raw == null) return null;
      return LatihanSettings.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (e) {
      print('Load Settings Error: $e');
      return null;
    }
  }

  Future<void> saveSettings(LatihanSettings settings) async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_settingsBoxName, _userEmail));
      final jsonStr = jsonEncode(settings.toJson());
      await box.put('current', jsonStr);
    } catch (e) {
      print('Save Settings Error: $e');
    }
  }

  // ─── ANALYSIS ────────────────────────────────────────────────────────────

  Future<String?> loadAnalysis() async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_analysisBoxName, _userEmail));
      return box.get('latest');
    } catch (e) {
      print('Load Analysis Error: $e');
      return null;
    }
  }

  Future<void> saveAnalysis(String analysis) async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_analysisBoxName, _userEmail));
      await box.put('latest', analysis);
    } catch (e) {
      print('Save Analysis Error: $e');
    }
  }

  // ─── CACHE ───────────────────────────────────────────────────────────────

  /// Buat cache key unik berdasarkan hash konten file + pengaturan
  String _buildCacheKey(String pdfText, LatihanSettings settings) {
    final raw =
        '${pdfText.length}_${settings.jumlahSoal}_${settings.babDipilih.join(',')}_${settings.persona.name}_${settings.level.name}';
    final bytes = utf8.encode(raw);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<List<SoalLatihan>?> loadFromCache(
      String pdfText, LatihanSettings settings) async {
    if (!settings.cachingAktif) return null;
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_hiveBoxBaseName, _userEmail));
      final key = _buildCacheKey(pdfText, settings);
      final cached = box.get(key);
      if (cached == null) return null;
      final list = jsonDecode(cached as String) as List;
      return list
          .asMap()
          .entries
          .map((e) => SoalLatihan.fromJson(e.value as Map<String, dynamic>,
              index: e.key))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToCache(
      String pdfText, LatihanSettings settings, List<SoalLatihan> soal) async {
    if (!settings.cachingAktif) return;
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_hiveBoxBaseName, _userEmail));
      final key = _buildCacheKey(pdfText, settings);
      final jsonStr = jsonEncode(soal.map((s) => s.toJson()).toList());
      await box.put(key, jsonStr);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox(SessionUtils.getDynamicBoxName(_hiveBoxBaseName, _userEmail));
      await box.clear();
    } catch (_) {}
  }

  // ─── PDF TEXT EXTRACTION ─────────────────────────────────────────────────

  /// Baca file PDF dan kembalikan teks mentah per bab
  Future<String> extractPdfText(
    String filePath, {
    List<String>? babDipilih,
    Function(String)? onLog,
  }) async {
    onLog?.call('📄 Mengekstrak teks PDF via Python...');
    final file = File(filePath);
    if (!file.existsSync()) throw Exception('File PDF tidak ditemukan.');

    try {
      // Gunakan PdfService yang memanggil Python PyMuPDF (PyMuPDF jauh lebih akurat)
      final rawText = await _pdfService.extractText(filePath);
      
      if (rawText.trim().isEmpty) {
        throw Exception('PDF kosong atau tidak dapat dibaca (mungkin berupa hasil scan tanpa OCR).');
      }

      onLog?.call('✅ PDF berhasil diekstrak (${rawText.length} karakter)');

      if (babDipilih == null ||
          babDipilih.isEmpty ||
          babDipilih.contains('Semua')) {
        return rawText;
      }

      // Filter per bab berdasarkan kata kunci
      return _filterByChapters(rawText, babDipilih, onLog: onLog);
    } catch (e) {
      onLog?.call('❌ Gagal ekstraksi: $e');
      rethrow;
    }
  }

  String _filterByChapters(String fullText, List<String> babDipilih,
      {Function(String)? onLog}) {
    final buffer = StringBuffer();
    for (final bab in babDipilih) {
      final babNum = bab.replaceAll(RegExp(r'[^0-9]'), '');
      // Cari pattern Bab/BAB/CHAPTER + nomor
      final patterns = [
        RegExp('BAB\\s+$babNum', caseSensitive: false),
        RegExp('CHAPTER\\s+$babNum', caseSensitive: false),
        RegExp('Bab\\s+$babNum', caseSensitive: false),
      ];

      int startIdx = -1;
      for (final p in patterns) {
        final m = p.firstMatch(fullText);
        if (m != null) {
          startIdx = m.start;
          break;
        }
      }

      if (startIdx == -1) {
        // Tidak ketemu marker bab, ambil porsi proporsional
        final chunkSize = fullText.length ~/ 5;
        final babIndex = int.tryParse(babNum) ?? 1;
        final start = (chunkSize * (babIndex - 1)).clamp(0, fullText.length);
        final end = (chunkSize * babIndex).clamp(0, fullText.length);
        buffer.write(fullText.substring(start, end));
        onLog?.call('📑 $bab: estimasi lokasi teks...');
      } else {
        // Cari bab berikutnya sebagai akhir
        int endIdx = fullText.length;
        final babNum2 = (int.tryParse(babNum) ?? 0) + 1;
        final nextPatterns = [
          RegExp('BAB\\s+$babNum2', caseSensitive: false),
          RegExp('CHAPTER\\s+$babNum2', caseSensitive: false),
          RegExp('Bab\\s+$babNum2', caseSensitive: false),
        ];
        for (final p in nextPatterns) {
          final m = p.firstMatch(fullText.substring(startIdx + 10));
          if (m != null) {
            endIdx = startIdx + 10 + m.start;
            break;
          }
        }
        final excerpt = fullText.substring(startIdx, endIdx);
        buffer.write('$excerpt\n\n');
        onLog?.call('📑 $bab: ${excerpt.length} karakter diekstrak');
      }
    }
    return buffer.toString();
  }

  // ─── GENERATE SOAL ───────────────────────────────────────────────────────

  Future<List<SoalLatihan>> generateSoal({
    required String pdfText,
    required LatihanSettings settings,
    Function(String)? onLog,
  }) async {
    // Secara default, jangan gunakan cache agar soal selalu baru saat klik "Mulai"
    // User bisa mengaktifkan cache lewat setting jika ingin menghemat.
    if (settings.cachingAktif) {
      onLog?.call('🔍 Memeriksa cache...');
      final cached = await loadFromCache(pdfText, settings);
      if (cached != null && cached.isNotEmpty) {
        onLog?.call('⚡ Soal ditemukan di cache! (${cached.length} soal)');
        return cached;
      }
      onLog?.call('💭 Cache kosong, generate soal baru...');
    } else {
      onLog?.call('🚀 Generating soal baru secara live...');
    }

    final provider = settings.provider ?? 'Google Gemini';
    onLog?.call('🤖 Menggunakan AI Provider: $provider...');
    onLog?.call('✍️ Membuat ${settings.jumlahSoal} soal ${settings.personaEmoji} ${settings.personaLabel}...');

    final systemPrompt = LatihanPrompt.buildSystemPrompt(settings.persona);
    // Tambahkan "Seed" unik agar AI selalu generate soal yang benar-benar baru
    final uniqueSeed = DateTime.now().millisecondsSinceEpoch;
    final userPrompt = "${LatihanPrompt.buildUserPrompt(
      pdfText: pdfText,
      jumlahSoal: settings.jumlahSoal,
      babDipilih: settings.babDipilih,
      persona: settings.persona,
      level: settings.level,
    )}\n\n[Unique Session ID: $uniqueSeed - Generate different and fresh questions than before] logic.";

    String rawResponse;
    try {
      rawResponse = await _aiService.extractCustom(
        systemPrompt: systemPrompt,
        userText: userPrompt,
        provider: provider,
        model: settings.model,
        onLog: onLog,
      );
    } catch (e) {
      throw Exception('Gagal generate soal dari $provider: $e');
    }

    onLog?.call('📥 Menerima respons AI, memproses soal...');

    final soalList = _parseJsonToSoal(rawResponse, onLog: onLog);
    if (soalList.isEmpty) {
      throw Exception('AI tidak menghasilkan soal yang valid. Coba lagi.');
    }

    onLog?.call('✅ ${soalList.length} soal berhasil dibuat!');

    // Simpan ke cache
    if (settings.cachingAktif) {
      await saveToCache(pdfText, settings, soalList);
      onLog?.call('💾 Soal disimpan ke cache.');
    }

    return soalList;
  }

  Future<String> generateAnalysis({
    required List<LatihanHistoryItem> history,
    required String? provider,
    required String? model,
  }) async {
    final prompt = LatihanPrompt.buildAnalysisPrompt(history);
    try {
      return await _aiService.extractCustom(
        systemPrompt: "Kamu adalah Mentor Skripsi AI yang memberikan feedback dari data statistik.",
        userText: prompt,
        provider: provider ?? 'Google Gemini',
        model: model,
        isJson: false,
      );
    } catch (e) {
      return "Gagal melakukan analisis otomatis: $e";
    }
  }

  List<SoalLatihan> _parseJsonToSoal(String rawText, {Function(String)? onLog}) {
    onLog?.call('🔍 Memulai parsing respons AI...');
    
    // Bersihkan markdown fences dan whitespace
    String cleaned = rawText
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Coba cari array langsung [ ... ]
    int startIdx = cleaned.indexOf('[');
    int endIdx = cleaned.lastIndexOf(']');

    // Jika tidak ada array, coba cari objek yang mungkin berisi array { "soal": [ ... ] }
    if (startIdx == -1) {
      onLog?.call('⚠️ Tidak menemukan format [array], mencari alternatif...');
      final objStart = cleaned.indexOf('{');
      final objEnd = cleaned.lastIndexOf('}');
      if (objStart != -1 && objEnd != -1) {
        try {
          final obj = jsonDecode(cleaned.substring(objStart, objEnd + 1)) as Map<String, dynamic>;
          // Cari field yang bertipe list
          for (final value in obj.values) {
            if (value is List) {
              onLog?.call('💡 Menemukan list di dalam objek AI.');
              return _listToSoal(value, onLog: onLog);
            }
          }
        } catch (_) {}
      }
    }

    if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
      onLog?.call('❌ Respons AI tidak mengandung JSON array yang valid.');
      onLog?.call('📄 Respons Mentah: ${rawText.length > 200 ? rawText.substring(0, 200) + '...' : rawText}');
      throw Exception('AI tidak memberikan format soal yang benar. Silakan coba lagi.');
    }

    cleaned = cleaned.substring(startIdx, endIdx + 1);

    try {
      final list = jsonDecode(cleaned) as List;
      return _listToSoal(list, onLog: onLog);
    } catch (e) {
      onLog?.call('❌ Gagal decode JSON: $e');
      throw Exception('Gagal memproses data soal dari AI.');
    }
  }

  List<SoalLatihan> _listToSoal(List list, {Function(String)? onLog}) {
    final results = <SoalLatihan>[];
    for (int i = 0; i < list.length; i++) {
      try {
        final item = list[i] as Map<String, dynamic>;
        final soal = SoalLatihan.fromJson(item, index: i);
        
        // Validasi minimal
        if (soal.pertanyaan.isNotEmpty && soal.pilihanA.isNotEmpty) {
          results.add(soal);
        } else {
          onLog?.call('⚠️ Soal #${i+1} dilewati karena data tidak lengkap.');
        }
      } catch (e) {
        onLog?.call('⚠️ Item #${i+1} bukan format soal yang valid.');
      }
    }
    return results;
  }
}
