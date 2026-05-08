class ChunkingService {
  static const int defaultChunkSize = 500; // ~500 words per chunk
  static const int defaultOverlap = 50; // ~50 word overlap

  /// Split text into overlapping chunks for RAG
  List<TextChunk> chunkText(
    String text, {
    int chunkSize = defaultChunkSize,
    int overlap = defaultOverlap,
  }) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <TextChunk>[];

    if (words.length <= chunkSize) {
      chunks.add(TextChunk(
        index: 0,
        content: text,
        startWord: 0,
        endWord: words.length,
      ));
      return chunks;
    }

    int startIndex = 0;
    int chunkIndex = 0;

    while (startIndex < words.length) {
      final endIndex = (startIndex + chunkSize).clamp(0, words.length);
      final chunkWords = words.sublist(startIndex, endIndex);

      chunks.add(TextChunk(
        index: chunkIndex,
        content: chunkWords.join(' '),
        startWord: startIndex,
        endWord: endIndex,
      ));

      startIndex += chunkSize - overlap;
      chunkIndex++;

      if (endIndex >= words.length) break;
    }

    return chunks;
  }

  /// Chunk text with page awareness (preserves page boundaries where possible)
  List<TextChunk> chunkTextWithPages(
    Map<int, String> pageTexts, {
    int chunkSize = defaultChunkSize,
    int overlap = defaultOverlap,
  }) {
    final chunks = <TextChunk>[];
    final buffer = StringBuffer();
    int bufferWordCount = 0;
    int chunkIndex = 0;
    int startPage = 1;
    int currentPage = 1;

    for (final entry in pageTexts.entries) {
      currentPage = entry.key;
      final pageWords = entry.value.split(RegExp(r'\s+'));

      for (final word in pageWords) {
        buffer.write('$word ');
        bufferWordCount++;

        if (bufferWordCount >= chunkSize) {
          chunks.add(TextChunk(
            index: chunkIndex,
            content: buffer.toString().trim(),
            startWord: 0,
            endWord: bufferWordCount,
            startPage: startPage,
            endPage: currentPage,
          ));

          // Keep overlap words
          final overlapText = buffer
              .toString()
              .trim()
              .split(RegExp(r'\s+'));
          final kept = overlapText
              .skip(overlapText.length - overlap)
              .join(' ');

          buffer.clear();
          buffer.write('$kept ');
          bufferWordCount = overlap;
          startPage = currentPage;
          chunkIndex++;
        }
      }
    }

    // Flush remaining buffer
    if (bufferWordCount > 0) {
      chunks.add(TextChunk(
        index: chunkIndex,
        content: buffer.toString().trim(),
        startWord: 0,
        endWord: bufferWordCount,
        startPage: startPage,
        endPage: currentPage,
      ));
    }

    return chunks;
  }
}

class TextChunk {
  final int index;
  final String content;
  final int startWord;
  final int endWord;
  final int? startPage;
  final int? endPage;

  TextChunk({
    required this.index,
    required this.content,
    required this.startWord,
    required this.endWord,
    this.startPage,
    this.endPage,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'content': content,
        'startWord': startWord,
        'endWord': endWord,
        'startPage': startPage,
        'endPage': endPage,
      };

  factory TextChunk.fromJson(Map<String, dynamic> json) => TextChunk(
        index: json['index'] as int,
        content: json['content'] as String,
        startWord: json['startWord'] as int,
        endWord: json['endWord'] as int,
        startPage: json['startPage'] as int?,
        endPage: json['endPage'] as int?,
      );
}
