import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

enum NumberingStyle { numeric, mixed }

class ChapterBlueprint {
  final String id;
  final String babLabel; 
  final String title;    
  final List<String> subChapters;
  final NumberingStyle style;

  ChapterBlueprint({
    required this.id,
    required this.babLabel,
    required this.title,
    this.subChapters = const [],
    this.style = NumberingStyle.numeric,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'babLabel': babLabel,
    'title': title,
    'subChapters': subChapters,
    'style': style.index,
  };

  factory ChapterBlueprint.fromJson(Map<String, dynamic> json) => ChapterBlueprint(
    id: json['id'],
    babLabel: json['babLabel'],
    title: json['title'],
    subChapters: List<String>.from(json['subChapters'] ?? []),
    style: NumberingStyle.values[json['style'] ?? 0],
  );

  ChapterBlueprint copyWith({
    String? babLabel,
    String? title,
    List<String>? subChapters,
    NumberingStyle? style,
  }) {
    return ChapterBlueprint(
      id: this.id,
      babLabel: babLabel ?? this.babLabel,
      title: title ?? this.title,
      subChapters: subChapters ?? this.subChapters,
      style: style ?? this.style,
    );
  }
}

class ResearchBlueprintState {
  final String judul;
  final String lokasi;
  final List<ChapterBlueprint> structure;
  final String? guidelinePath;
  final String? selectedProvider;
  final String? selectedModel;
  final String populationType; // 'finite' or 'infinite'
  final int? populationCount;  // only used when finite

  ResearchBlueprintState({
    this.judul = '',
    this.lokasi = '',
    this.structure = const [],
    this.guidelinePath,
    this.selectedProvider,
    this.selectedModel,
    this.populationType = 'infinite',
    this.populationCount,
  });

  String get kerangkaAsText {
    return structure.map((c) => '${c.babLabel} ${c.title}:\n${c.subChapters.join("\n")}').join("\n\n");
  }

  ResearchBlueprintState copyWith({
    String? judul,
    String? lokasi,
    List<ChapterBlueprint>? structure,
    String? guidelinePath,
    String? selectedProvider,
    String? selectedModel,
    String? populationType,
    int? populationCount,
    bool clearPopulationCount = false,
    bool clearGuideline = false,
  }) {
    return ResearchBlueprintState(
      judul: judul ?? this.judul,
      lokasi: lokasi ?? this.lokasi,
      structure: structure ?? this.structure,
      guidelinePath: clearGuideline ? null : (guidelinePath ?? this.guidelinePath),
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedModel: selectedModel ?? this.selectedModel,
      populationType: populationType ?? this.populationType,
      populationCount: clearPopulationCount ? null : (populationCount ?? this.populationCount),
    );
  }
}

class ResearchBlueprintNotifier extends StateNotifier<ResearchBlueprintState> {
  ResearchBlueprintNotifier() : super(ResearchBlueprintState()) {
    _loadFromHive();
  }

  static const String _boxName = 'research_blueprint_v3';

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox(_boxName);
    final String? structJson = box.get('structure');
    
    List<ChapterBlueprint> loadedStructure = [];
    if (structJson != null) {
      final List<dynamic> decoded = jsonDecode(structJson);
      loadedStructure = decoded.map((j) => ChapterBlueprint.fromJson(j)).toList();
    } else {
      loadedStructure = [
        ChapterBlueprint(id: '1', babLabel: 'Bab 1', title: 'Pendahuluan', subChapters: []),
      ];
    }

    state = ResearchBlueprintState(
      judul: box.get('judul', defaultValue: ''),
      lokasi: box.get('lokasi', defaultValue: ''),
      structure: loadedStructure,
      guidelinePath: box.get('guidelinePath'),
      selectedProvider: box.get('selectedProvider', defaultValue: 'Google Gemini'),
      selectedModel: box.get('selectedModel'),
      populationType: box.get('populationType', defaultValue: 'infinite'),
      populationCount: box.get('populationCount'),
    );
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox(_boxName);
    await box.put('judul', state.judul);
    await box.put('lokasi', state.lokasi);
    await box.put('guidelinePath', state.guidelinePath);
    await box.put('selectedProvider', state.selectedProvider);
    await box.put('selectedModel', state.selectedModel);
    await box.put('populationType', state.populationType);
    await box.put('populationCount', state.populationCount);
    final String structJson = jsonEncode(state.structure.map((c) => c.toJson()).toList());
    await box.put('structure', structJson);
  }

  Future<void> updateJudul(String value) async {
    state = state.copyWith(judul: value);
    _saveToHive();
  }

  Future<void> updateLokasi(String value) async {
    state = state.copyWith(lokasi: value);
    _saveToHive();
  }

  Future<void> updateGuidelinePath(String? path) async {
    state = state.copyWith(guidelinePath: path, clearGuideline: path == null);
    _saveToHive();
  }

  Future<void> updateAIConfig({String? provider, String? model}) async {
    state = state.copyWith(selectedProvider: provider, selectedModel: model);
    _saveToHive();
  }

  Future<void> updatePopulation({String? type, int? count}) async {
    state = state.copyWith(
      populationType: type,
      populationCount: count,
      clearPopulationCount: type == 'infinite',
    );
    _saveToHive();
  }

  void addChapter() {
    final nextNum = state.structure.length + 1;
    final newChapter = ChapterBlueprint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      babLabel: 'Bab $nextNum',
      title: '',
      subChapters: [],
    );
    state = state.copyWith(structure: [...state.structure, newChapter]);
    _saveToHive();
  }

  void removeChapter(String id) {
    state = state.copyWith(
      structure: state.structure.where((c) => c.id != id).toList(),
    );
    _saveToHive();
  }

  void updateChapter(String id, {String? babLabel, String? title, List<String>? subChapters, NumberingStyle? style}) {
    state = state.copyWith(
      structure: state.structure.map((c) {
        if (c.id == id) {
          return c.copyWith(babLabel: babLabel, title: title, subChapters: subChapters, style: style);
        }
        return c;
      }).toList(),
    );
    _saveToHive();
  }

  void setFullStructure(List<ChapterBlueprint> newStructure) {
    state = state.copyWith(structure: newStructure);
    _saveToHive();
  }
}

final researchBlueprintProvider =
    StateNotifierProvider<ResearchBlueprintNotifier, ResearchBlueprintState>((ref) {
  return ResearchBlueprintNotifier();
});
