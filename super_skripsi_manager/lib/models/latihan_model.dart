/// Models untuk fitur Latihan Skripsi
library latihan_model;

enum PersonaDosen { ramah, sedang, killer }
enum LatihanLevel { level1, level2, level3 }

enum LatihanStatus { idle, generating, active, selesai, error }

class SoalLatihan {
  final int nomorSoal;
  final String bab;
  final String pertanyaan;
  final String pilihanA;
  final String pilihanB;
  final String pilihanC;
  final String pilihanD;
  final String jawabanBenar; // 'A', 'B', 'C', atau 'D'
  final String penjelasanBenar;
  final String penjelasanSalahA;
  final String penjelasanSalahB;
  final String penjelasanSalahC;
  final String penjelasanSalahD;

  const SoalLatihan({
    required this.nomorSoal,
    required this.bab,
    required this.pertanyaan,
    required this.pilihanA,
    required this.pilihanB,
    required this.pilihanC,
    required this.pilihanD,
    required this.jawabanBenar,
    required this.penjelasanBenar,
    required this.penjelasanSalahA,
    required this.penjelasanSalahB,
    required this.penjelasanSalahC,
    required this.penjelasanSalahD,
  });

  factory SoalLatihan.fromJson(Map<String, dynamic> json, {int index = 0}) {
    // Mapping kunci alternatif (Bahasa Inggris vs Indonesia)
    final q = json['pertanyaan'] ?? json['question'] ?? '';
    
    // Mapping Pilihan (bisa berupa list 'options' atau individual 'pilihanA/B/C/D')
    final options = json['options'] as List?;
    String pA = json['pilihanA']?.toString() ?? (options != null && options.length > 0 ? options[0].toString() : '');
    String pB = json['pilihanB']?.toString() ?? (options != null && options.length > 1 ? options[1].toString() : '');
    String pC = json['pilihanC']?.toString() ?? (options != null && options.length > 2 ? options[2].toString() : '');
    String pD = json['pilihanD']?.toString() ?? (options != null && options.length > 3 ? options[3].toString() : '');
    
    // Mapping Jawaban & Penjelasan
    String ans = (json['jawabanBenar'] ?? json['answer'] ?? 'A').toString().toUpperCase();
    if (ans.length > 1) ans = ans[0]; // Ambil karakter pertama saja jika AI menjawab "A. Jawaban"
    
    // Handle format lama (penjelasan tunggal)
    final expl = json['penjelasan'] ?? json['explanation'] ?? '';

    // Handle format baru (penjelasan spesifik)
    final explBenar = json['penjelasanBenar'] ?? expl;
    final explA = json['penjelasanSalahA'] ?? '';
    final explB = json['penjelasanSalahB'] ?? '';
    final explC = json['penjelasanSalahC'] ?? '';
    final explD = json['penjelasanSalahD'] ?? '';

    return SoalLatihan(
      nomorSoal: (json['nomorSoal'] as num?)?.toInt() ?? (index + 1),
      bab: json['bab']?.toString() ?? 'Umum',
      pertanyaan: q.toString(),
      pilihanA: pA,
      pilihanB: pB,
      pilihanC: pC,
      pilihanD: pD,
      jawabanBenar: ans,
      penjelasanBenar: explBenar.toString(),
      penjelasanSalahA: explA.toString(),
      penjelasanSalahB: explB.toString(),
      penjelasanSalahC: explC.toString(),
      penjelasanSalahD: explD.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nomorSoal': nomorSoal,
        'bab': bab,
        'pertanyaan': pertanyaan,
        'pilihanA': pilihanA,
        'pilihanB': pilihanB,
        'pilihanC': pilihanC,
        'pilihanD': pilihanD,
        'jawabanBenar': jawabanBenar,
        'penjelasanBenar': penjelasanBenar,
        'penjelasanSalahA': penjelasanSalahA,
        'penjelasanSalahB': penjelasanSalahB,
        'penjelasanSalahC': penjelasanSalahC,
        'penjelasanSalahD': penjelasanSalahD,
      };

  String getPilihan(String key) {
    switch (key.toUpperCase()) {
      case 'A':
        return pilihanA;
      case 'B':
        return pilihanB;
      case 'C':
        return pilihanC;
      case 'D':
        return pilihanD;
      default:
        return '';
    }
  }
}

class LatihanSettings {
  final int jumlahSoal;
  final List<String> babDipilih; // ['Bab 1', 'Bab 2', ...] atau ['Semua']
  final String? provider;
  final String? model;
  final String? apiKeyName;
  final PersonaDosen persona;
  final LatihanLevel level;
  final bool timerAktif;
  final int timerMenit;
  final bool cachingAktif;
  final String? namaFile;
  final String? filePath;

  const LatihanSettings({
    this.jumlahSoal = 10,
    this.babDipilih = const ['Semua'],
    this.provider,
    this.model,
    this.apiKeyName,
    this.persona = PersonaDosen.sedang,
    this.level = LatihanLevel.level1,
    this.timerAktif = false,
    this.timerMenit = 30,
    this.cachingAktif = false,
    this.namaFile,
    this.filePath,
  });

  LatihanSettings copyWith({
    int? jumlahSoal,
    List<String>? babDipilih,
    String? provider,
    String? model,
    String? apiKeyName,
    PersonaDosen? persona,
    LatihanLevel? level,
    bool? timerAktif,
    int? timerMenit,
    bool? cachingAktif,
    String? namaFile,
    String? filePath,
    bool clearProvider = false,
    bool clearModel = false,
  }) {
    return LatihanSettings(
      jumlahSoal: jumlahSoal ?? this.jumlahSoal,
      babDipilih: babDipilih ?? this.babDipilih,
      provider: clearProvider ? null : (provider ?? this.provider),
      model: clearModel ? null : (model ?? this.model),
      apiKeyName: apiKeyName ?? this.apiKeyName,
      persona: persona ?? this.persona,
      level: level ?? this.level,
      timerAktif: timerAktif ?? this.timerAktif,
      timerMenit: timerMenit ?? this.timerMenit,
      cachingAktif: cachingAktif ?? this.cachingAktif,
      namaFile: namaFile ?? this.namaFile,
      filePath: filePath ?? this.filePath,
    );
  }

  String get personaLabel {
    switch (persona) {
      case PersonaDosen.ramah:
        return 'Ramah';
      case PersonaDosen.sedang:
        return 'Sedang';
      case PersonaDosen.killer:
        return 'Killer';
    }
  }

  String get personaEmoji {
    switch (persona) {
      case PersonaDosen.ramah:
        return '😊';
      case PersonaDosen.sedang:
        return '📖';
      case PersonaDosen.killer:
        return '😈';
    }
  }

  String get personaDeskripsi {
    switch (persona) {
      case PersonaDosen.ramah:
        return 'Soal konseptual, bahasa ramah & mudah dipahami';
      case PersonaDosen.sedang:
        return 'Campuran konseptual & analitis, bahasa netral';
      case PersonaDosen.killer:
        return 'Soal detail & teknis tinggi, bahasa formal tajam';
    }
  }

  String get levelLabel {
    switch (level) {
      case LatihanLevel.level1:
        return 'Level 1';
      case LatihanLevel.level2:
        return 'Level 2';
      case LatihanLevel.level3:
        return 'Level 3';
    }
  }

  String get levelNama {
    switch (level) {
      case LatihanLevel.level1:
        return 'Pemahaman Dasar';
      case LatihanLevel.level2:
        return 'Analisis Logika';
      case LatihanLevel.level3:
        return 'Pertahanan Kritis';
    }
  }

  String get levelDeskripsi {
    switch (level) {
      case LatihanLevel.level1:
        return 'Fokus pada apa yang tertulis secara eksplisit (Fakta & Teori)';
      case LatihanLevel.level2:
        return 'Fokus pada keterkaitan antar bagian (Logika & Prosedur)';
      case LatihanLevel.level3:
        return 'Fokus pada evaluasi mendalam dan skenario kritis (HOTS)';
    }
  }

  String get babLabel {
    if (babDipilih.contains('Semua') || babDipilih.length == 5) return 'Semua Bab';
    return babDipilih.join(', ');
  }

  factory LatihanSettings.fromJson(Map<String, dynamic> json) {
    return LatihanSettings(
      jumlahSoal: json['jumlahSoal'] ?? 10,
      babDipilih: (json['babDipilih'] as List?)?.map((e) => e.toString()).toList() ?? const ['Semua'],
      provider: json['provider'],
      model: json['model'],
      apiKeyName: json['apiKeyName'],
      persona: PersonaDosen.values.firstWhere((e) => e.name == json['persona'], orElse: () => PersonaDosen.sedang),
      level: LatihanLevel.values.firstWhere((e) => e.name == json['level'], orElse: () => LatihanLevel.level1),
      timerAktif: json['timerAktif'] ?? false,
      timerMenit: json['timerMenit'] ?? 30,
      cachingAktif: json['cachingAktif'] ?? false,
      namaFile: json['namaFile'],
      filePath: json['filePath'],
    );
  }

  Map<String, dynamic> toJson() => {
    'jumlahSoal': jumlahSoal,
    'babDipilih': babDipilih,
    'provider': provider,
    'model': model,
    'apiKeyName': apiKeyName,
    'persona': persona.name,
    'level': level.name,
    'timerAktif': timerAktif,
    'timerMenit': timerMenit,
    'cachingAktif': cachingAktif,
    'namaFile': namaFile,
    'filePath': filePath,
  };
}

class LatihanSession {
  final List<SoalLatihan> soalList;
  final Map<int, String> jawabanUser; // nomorSoal → pilihan user ('A', 'B', 'C', 'D')
  final Map<int, bool> sudahDijawab; // nomorSoal → apakah sudah dijawab
  final LatihanStatus status;
  final String? errorMessage;
  final List<String> generateLogs;
  final DateTime? waktuMulai;
  final DateTime? waktuSelesai;
  final int soalAktifIndex;
  final LatihanSettings settings;

  const LatihanSession({
    this.soalList = const [],
    this.jawabanUser = const {},
    this.sudahDijawab = const {},
    this.status = LatihanStatus.idle,
    this.errorMessage,
    this.generateLogs = const [],
    this.waktuMulai,
    this.waktuSelesai,
    this.soalAktifIndex = 0,
    this.settings = const LatihanSettings(),
  });

  LatihanSession copyWith({
    List<SoalLatihan>? soalList,
    Map<int, String>? jawabanUser,
    Map<int, bool>? sudahDijawab,
    LatihanStatus? status,
    String? errorMessage,
    List<String>? generateLogs,
    DateTime? waktuMulai,
    DateTime? waktuSelesai,
    int? soalAktifIndex,
    LatihanSettings? settings,
  }) {
    return LatihanSession(
      soalList: soalList ?? this.soalList,
      jawabanUser: jawabanUser ?? this.jawabanUser,
      sudahDijawab: sudahDijawab ?? this.sudahDijawab,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      generateLogs: generateLogs ?? this.generateLogs,
      waktuMulai: waktuMulai ?? this.waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      soalAktifIndex: soalAktifIndex ?? this.soalAktifIndex,
      settings: settings ?? this.settings,
    );
  }

  /// Hitung skor (0-100)
  int get skor {
    if (soalList.isEmpty) return 0;
    int benar = 0;
    for (final soal in soalList) {
      final jawaban = jawabanUser[soal.nomorSoal];
      if (jawaban != null && jawaban == soal.jawabanBenar) benar++;
    }
    return ((benar / soalList.length) * 100).round();
  }

  int get jumlahBenar {
    int benar = 0;
    for (final soal in soalList) {
      final jawaban = jawabanUser[soal.nomorSoal];
      if (jawaban != null && jawaban == soal.jawabanBenar) benar++;
    }
    return benar;
  }

  int get jumlahSalah => soalList.length - jumlahBenar;

  int get jumlahBelumDijawab =>
      soalList.where((s) => !sudahDijawab.containsKey(s.nomorSoal)).length;

  bool get semuaSudahDijawab => jumlahBelumDijawab == 0;

  SoalLatihan? get soalAktif =>
      soalAktifIndex < soalList.length ? soalList[soalAktifIndex] : null;

  /// Breakdown per bab: {'Bab 1': {'benar': 3, 'total': 5}, ...}
  Map<String, Map<String, int>> get breakdownPerBab {
    final result = <String, Map<String, int>>{};
    for (final soal in soalList) {
      result[soal.bab] ??= {'benar': 0, 'total': 0};
      result[soal.bab]!['total'] = result[soal.bab]!['total']! + 1;
      final jawaban = jawabanUser[soal.nomorSoal];
      if (jawaban == soal.jawabanBenar) {
        result[soal.bab]!['benar'] = result[soal.bab]!['benar']! + 1;
      }
    }
    return result;
  }
}

class LatihanHistoryItem {
  final String id;
  final String fileName;
  final DateTime date;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final List<SoalLatihan> soalList;
  final Map<int, String> jawabanUser;
  final LatihanSettings settings;

  const LatihanHistoryItem({
    required this.id,
    required this.fileName,
    required this.date,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.soalList,
    required this.jawabanUser,
    required this.settings,
  });

  factory LatihanHistoryItem.fromJson(Map<String, dynamic> json) {
    return LatihanHistoryItem(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      date: DateTime.parse(json['date'] as String),
      score: json['score'] as int,
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      soalList: (json['soalList'] as List)
          .map((e) => SoalLatihan.fromJson(e as Map<String, dynamic>))
          .toList(),
      jawabanUser: (json['jawabanUser'] as Map?)?.map(
            (k, v) => MapEntry(int.parse(k.toString()), v.toString()),
          ) ??
          {},
      settings: LatihanSettings(
        jumlahSoal: json['totalQuestions'] as int,
        namaFile: json['fileName'] as String,
        persona: PersonaDosen.values.firstWhere(
          (p) => p.name == json['persona'],
          orElse: () => PersonaDosen.sedang,
        ),
        level: LatihanLevel.values.firstWhere(
          (l) => l.name == json['level'],
          orElse: () => LatihanLevel.level1,
        ),
        babDipilih: (json['babDipilih'] as List?)?.map((e) => e.toString()).toList() ?? const ['Semua'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'date': date.toIso8601String(),
        'score': score,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'soalList': soalList.map((e) => e.toJson()).toList(),
        'jawabanUser': jawabanUser.map((k, v) => MapEntry(k.toString(), v)),
        'persona': settings.persona.name,
        'level': settings.level.name,
        'babDipilih': settings.babDipilih,
      };
}

