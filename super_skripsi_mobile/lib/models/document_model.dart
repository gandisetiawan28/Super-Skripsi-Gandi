class DocumentModel {
  final String id;
  final String originalFileName;
  final String renamedFileName;
  final String title;
  final List<String> authors;
  final String? year;
  final String? category;
  final String? translatedTitle;
  final String? translatedCategory;
  final String textContent;
  final String md5Hash;
  final int chunkCount;
  final DateTime createdAt;
  final String? risData;
  final String? filePath;

  // New Journal Fields for RIS
  final String? journalName;
  final String? volume;
  final String? issue;
  final String? pages;
  // Document type fields (from AI detection)
  final String? documentType;       // JOUR, BOOK, THES, CONF, RPRT
  final String? publisher;          // Penerbit / Universitas
  final String? isbn;               // ISBN (untuk buku)
  final String? placeOfPublication; // Kota terbit

  DocumentModel({
    required this.id,
    required this.originalFileName,
    required this.renamedFileName,
    required this.title,
    required this.authors,
    this.year,
    this.category,
    this.translatedTitle,
    this.translatedCategory,
    required this.textContent,
    required this.md5Hash,
    this.chunkCount = 0,
    required this.createdAt,
    this.risData,
    this.filePath,
    this.journalName,
    this.volume,
    this.issue,
    this.pages,
    this.documentType,
    this.publisher,
    this.isbn,
    this.placeOfPublication,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalFileName': originalFileName,
        'renamedFileName': renamedFileName,
        'title': title,
        'authors': authors,
        'year': year,
        'category': category,
        'translatedTitle': translatedTitle,
        'translatedCategory': translatedCategory,
        'textContent': textContent,
        'md5Hash': md5Hash,
        'chunkCount': chunkCount,
        'createdAt': createdAt.toIso8601String(),
        'risData': risData,
        'filePath': filePath,
        'journalName': journalName,
        'volume': volume,
        'issue': issue,
        'pages': pages,
        'documentType': documentType,
        'publisher': publisher,
        'isbn': isbn,
        'placeOfPublication': placeOfPublication,
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        id: json['id'] as String,
        originalFileName: json['originalFileName'] as String,
        renamedFileName: json['renamedFileName'] as String,
        title: json['title'] as String,
        authors: List<String>.from(json['authors'] as List),
        year: json['year'] as String?,
        category: json['category'] as String?,
        translatedTitle: json['translatedTitle'] as String?,
        translatedCategory: json['translatedCategory'] as String?,
        textContent: json['textContent'] as String,
        md5Hash: json['md5Hash'] as String,
        chunkCount: json['chunkCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        risData: json['risData'] as String?,
        filePath: json['filePath'] as String?,
        journalName: json['journalName'] as String?,
        volume: json['volume'] as String?,
        issue: json['issue'] as String?,
        pages: json['pages'] as String?,
        documentType: json['documentType'] as String?,
        publisher: json['publisher'] as String?,
        isbn: json['isbn'] as String?,
        placeOfPublication: json['placeOfPublication'] as String?,
      );

  /// Metadata-only version for API responses (no full text)
  Map<String, dynamic> toMetadataJson() => {
        'id': id,
        'originalFileName': originalFileName,
        'renamedFileName': renamedFileName,
        'title': title,
        'authors': authors,
        'year': year,
        'category': category,
        'translatedTitle': translatedTitle,
        'translatedCategory': translatedCategory,
        'md5Hash': md5Hash,
        'chunkCount': chunkCount,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Generate APA-style renamed filename: Lastname (Year) - Judul
  String get apaFileName {
    String authorStr = '';
    if (authors.isEmpty || (authors.length == 1 && authors.first.toLowerCase().contains('unknown'))) {
      authorStr = 'Unknown';
    } else if (authors.length == 1) {
      final parts = authors.first.trim().split(' ');
      authorStr = parts.last;
    } else if (authors.length == 2) {
      final last1 = authors[0].trim().split(' ').last;
      final last2 = authors[1].trim().split(' ').last;
      authorStr = '$last1 & $last2';
    } else {
      final last1 = authors.first.trim().split(' ').last;
      authorStr = '$last1 et al.';
    }

    final yearStr = year != null ? '($year)' : '(n.d.)';
    
    // Sanitize title: remove symbols, and common journal artifacts, max 50 chars
    String safeTitle = title
        .replaceAll(RegExp(r'Volume \d+|Journal of|Number \d+|ISSN \d+-\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    
    if (safeTitle.length > 50) {
      safeTitle = safeTitle.substring(0, 50).trim();
    }
    
    if (safeTitle.isEmpty) safeTitle = 'Research-Document';
    
    return '$authorStr $yearStr - $safeTitle.pdf';
  }
}
