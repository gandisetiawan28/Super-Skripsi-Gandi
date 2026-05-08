class AcademicPaper {
  final String id;
  final String title;
  final List<String> authors;
  final int? year;
  final String? abstract;
  final int? citationCount;
  final String? url;

  AcademicPaper({
    required this.id,
    required this.title,
    required this.authors,
    this.year,
    this.abstract,
    this.citationCount,
    this.url,
  });

  factory AcademicPaper.fromJson(Map<String, dynamic> json) {
    return AcademicPaper(
      id: json['paperId'] ?? '',
      title: json['title'] ?? 'No Title',
      authors: (json['authors'] as List? ?? [])
          .map((a) => a['name'] as String)
          .toList(),
      year: json['year'],
      abstract: json['abstract'],
      citationCount: json['citationCount'],
      url: json['url'],
    );
  }
}
