import '../models/document_model.dart';

class RisGeneratorService {
  /// Generate RIS format string for Mendeley import
  String generateRis(DocumentModel doc) {
    final buffer = StringBuffer();

    // Deteksi tipe dokumen dari field documentType
    // Default ke JOUR jika tidak ada data (backwards-compatible)
    final String risType = _resolveRisType(doc);
    buffer.writeln('TY  - $risType');
    buffer.writeln('TI  - ${doc.title}');

    for (final author in doc.authors) {
      // RIS format: Last, First Middle
      final parts = author.split(' ');
      if (parts.length >= 2) {
        final lastName = parts.last;
        final firstName = parts.sublist(0, parts.length - 1).join(' ');
        buffer.writeln('AU  - $lastName, $firstName');
      } else {
        buffer.writeln('AU  - $author');
      }
    }

    if (doc.year != null) {
      buffer.writeln('PY  - ${doc.year}');
      buffer.writeln('DA  - ${doc.year}///');
    }

    // Field khusus berdasarkan tipe
    if (risType == 'JOUR' || risType == 'CONF') {
      // Artikel Jurnal & Prosiding: journal, volume, issue, halaman
      if (doc.journalName != null && doc.journalName != 'Unknown') {
        buffer.writeln('JO  - ${doc.journalName}');
        buffer.writeln('T2  - ${doc.journalName}');
      }
      if (doc.volume != null && doc.volume != 'Unknown') {
        buffer.writeln('VL  - ${doc.volume}');
      }
      if (doc.issue != null && doc.issue != 'Unknown') {
        buffer.writeln('IS  - ${doc.issue}');
      }
      if (doc.pages != null && doc.pages != 'Unknown') {
        final pageParts = doc.pages!.split(RegExp(r'[-–—]'));
        if (pageParts.length >= 2) {
          buffer.writeln('SP  - ${pageParts[0].trim()}');
          buffer.writeln('EP  - ${pageParts[1].trim()}');
        } else {
          buffer.writeln('SP  - ${doc.pages}');
        }
      }
    } else if (risType == 'BOOK') {
      // Buku/Ebook: penerbit, kota terbit, ISBN
      if (doc.publisher != null && doc.publisher != 'Unknown') {
        buffer.writeln('PB  - ${doc.publisher}');
      }
      if (doc.placeOfPublication != null && doc.placeOfPublication != 'Unknown') {
        buffer.writeln('CY  - ${doc.placeOfPublication}');
      }
      if (doc.isbn != null && doc.isbn != 'Unknown') {
        buffer.writeln('SN  - ${doc.isbn}');
      }
    } else if (risType == 'THES') {
      // Skripsi/Tesis: nama universitas sebagai penerbit
      if (doc.publisher != null && doc.publisher != 'Unknown') {
        buffer.writeln('PB  - ${doc.publisher}');
      }
      if (doc.placeOfPublication != null && doc.placeOfPublication != 'Unknown') {
        buffer.writeln('CY  - ${doc.placeOfPublication}');
      }
    }

    // Field umum untuk semua tipe
    if (doc.category != null) {
      // Split kategori dengan koma jadi multiple KW
      final keywords = doc.category!.split(',');
      for (final kw in keywords) {
        final trimmed = kw.trim();
        if (trimmed.isNotEmpty) {
          buffer.writeln('KW  - $trimmed');
        }
      }
    }

    buffer.writeln('ER  - ');
    buffer.writeln();

    return buffer.toString();
  }

  /// Resolve RIS type tag dari doc metadata — sistem skoring multi-sinyal
  String _resolveRisType(DocumentModel doc) {
    // ── Prioritas 1: Gunakan hasil deteksi AI jika tersedia ──
    if (doc.documentType != null) {
      final t = doc.documentType!.toUpperCase().trim();
      if (['JOUR', 'BOOK', 'THES', 'CONF', 'RPRT'].contains(t)) return t;
    }

    // ── Prioritas 2: Heuristik Multi-Sinyal ──
    int scoreJour = 0;
    int scoreBook = 0;
    int scoreThes = 0;
    int scoreConf = 0;

    final title = doc.title.toLowerCase();
    final journalName = (doc.journalName ?? '').toLowerCase();
    final publisher = (doc.publisher ?? '').toLowerCase();

    // Sinyal dari Judul
    for (final kw in ['buku ajar', 'buku teks', 'textbook', 'handbook', 'panduan lengkap',
                      'modul', 'pengantar', 'dasar-dasar', 'ensiklopedi', 'kamus', 'antologi']) {
      if (title.contains(kw)) scoreBook += 3;
    }
    for (final kw in ['pengaruh', 'hubungan', 'analisis', 'faktor', 'dampak', 'efektivitas',
                      'studi', 'kajian', 'peran', 'implementasi', 'evaluasi', 'persepsi',
                      'korelasi', 'determinan', 'mediasi', 'moderasi']) {
      if (title.contains(kw)) scoreJour += 1;
    }
    for (final kw in ['skripsi', 'tesis', 'disertasi', 'tugas akhir', 'thesis', 'dissertation']) {
      if (title.contains(kw)) scoreThes += 5;
    }
    for (final kw in ['prosiding', 'proceeding', 'seminar nasional', 'conference paper',
                      'seminar internasional', 'symposium']) {
      if (title.contains(kw)) scoreConf += 5;
    }

    // Sinyal dari Nama Jurnal
    if (journalName.isNotEmpty && journalName != 'unknown') {
      scoreJour += 4;
      if (journalName.contains('prosiding') || journalName.contains('proceeding') ||
          journalName.contains('seminar') || journalName.contains('conference')) {
        scoreConf += 3;
        scoreJour -= 2;
      }
    }

    // Sinyal dari Penerbit
    if (publisher.isNotEmpty && publisher != 'unknown') {
      scoreBook += 4;
      for (final pub in ['gramedia', 'erlangga', 'alfabeta', 'bumi aksara', 'kencana',
                         'andi', 'prenada', 'salemba', 'ghalia', 'deepublish', 'cv ',
                         'pt ', 'penerbit', 'publisher', 'press', 'publishing']) {
        if (publisher.contains(pub)) { scoreBook += 2; break; }
      }
      for (final uni in ['universitas', 'university', 'institut', 'politeknik', 'sekolah tinggi']) {
        if (publisher.contains(uni)) { scoreThes += 2; scoreBook -= 1; break; }
      }
    }

    // Sinyal dari Volume/Issue/Halaman
    if (doc.volume != null && doc.volume != 'null' && doc.volume!.isNotEmpty) scoreJour += 3;
    if (doc.issue != null && doc.issue != 'null' && doc.issue!.isNotEmpty) scoreJour += 2;
    if (doc.pages != null && doc.pages != 'null' && doc.pages!.isNotEmpty) {
      scoreJour += 1;
      final pageMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(doc.pages!);
      if (pageMatch != null) {
        final start = int.tryParse(pageMatch.group(1) ?? '0') ?? 0;
        final end = int.tryParse(pageMatch.group(2) ?? '0') ?? 0;
        if (end - start < 30) scoreJour += 2;
        else if (end - start > 50) scoreBook += 2;
      }
    }

    // Sinyal dari ISBN (sangat kuat = buku)
    if (doc.isbn != null && doc.isbn!.isNotEmpty && doc.isbn != 'null') {
      scoreBook += 5;
    }

    // Pilih tipe dengan skor tertinggi
    final scores = {'JOUR': scoreJour, 'BOOK': scoreBook, 'THES': scoreThes, 'CONF': scoreConf};
    final winner = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (winner.value <= 0) return 'JOUR';
    return winner.key;
  }

  /// Generate RIS for multiple documents
  String generateBatchRis(List<DocumentModel> docs) {
    return docs.map(generateRis).join('\n');
  }
}
