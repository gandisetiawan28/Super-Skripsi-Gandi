import 'dart:convert';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'chunking_service.dart';
import '../utils/session_utils.dart';

class VectorStoreService {
  Database? _db;
  final String? _userEmail;

  VectorStoreService(this._userEmail);

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final appDir = await getApplicationSupportDirectory();
    final safeEmail = SessionUtils.getSafeEmail(_userEmail);
    final dbPath = p.join(appDir.path, 'super_skripsi', 'vector_store_$safeEmail.db');

    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS documents (
              id TEXT PRIMARY KEY,
              original_filename TEXT NOT NULL,
              renamed_filename TEXT NOT NULL,
              title TEXT NOT NULL,
              authors TEXT NOT NULL,
              year TEXT,
              category TEXT,
              text_content TEXT NOT NULL,
              md5_hash TEXT UNIQUE NOT NULL,
              chunk_count INTEGER DEFAULT 0,
              ris_data TEXT,
              file_path TEXT,
              journal_name TEXT,
              volume TEXT,
              issue TEXT,
              pages TEXT,
              translated_title TEXT,
              translated_category TEXT,
              document_type TEXT,
              publisher TEXT,
              isbn TEXT,
              place_of_publication TEXT,
              created_at TEXT NOT NULL
            )
          ''');

          // Migration: Add new columns if missing
          final migrations = [
            'ALTER TABLE documents ADD COLUMN file_path TEXT',
            'ALTER TABLE documents ADD COLUMN journal_name TEXT',
            'ALTER TABLE documents ADD COLUMN volume TEXT',
            'ALTER TABLE documents ADD COLUMN issue TEXT',
            'ALTER TABLE documents ADD COLUMN pages TEXT',
            'ALTER TABLE documents ADD COLUMN translated_title TEXT',
            'ALTER TABLE documents ADD COLUMN translated_category TEXT',
            'ALTER TABLE documents ADD COLUMN document_type TEXT',
            'ALTER TABLE documents ADD COLUMN publisher TEXT',
            'ALTER TABLE documents ADD COLUMN isbn TEXT',
            'ALTER TABLE documents ADD COLUMN place_of_publication TEXT',
          ];

          for (final sql in migrations) {
            try {
              await db.execute(sql);
            } catch (_) {}
          }

          await db.execute('''
            CREATE TABLE IF NOT EXISTS chunks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              document_id TEXT NOT NULL,
              chunk_index INTEGER NOT NULL,
              content TEXT NOT NULL,
              start_word INTEGER,
              end_word INTEGER,
              start_page INTEGER,
              end_page INTEGER,
              tfidf_vector TEXT,
              FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_chunks_document_id 
            ON chunks(document_id)
          ''');

          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_documents_hash 
            ON documents(md5_hash)
          ''');
        },
        onOpen: (db) async {
          // Migration: Add new columns if missing
          final migrations = [
            'ALTER TABLE documents ADD COLUMN file_path TEXT',
            'ALTER TABLE documents ADD COLUMN journal_name TEXT',
            'ALTER TABLE documents ADD COLUMN volume TEXT',
            'ALTER TABLE documents ADD COLUMN issue TEXT',
            'ALTER TABLE documents ADD COLUMN pages TEXT',
            'ALTER TABLE documents ADD COLUMN translated_title TEXT',
            'ALTER TABLE documents ADD COLUMN translated_category TEXT',
            'ALTER TABLE documents ADD COLUMN document_type TEXT',
            'ALTER TABLE documents ADD COLUMN publisher TEXT',
            'ALTER TABLE documents ADD COLUMN isbn TEXT',
            'ALTER TABLE documents ADD COLUMN place_of_publication TEXT',
          ];

          for (final sql in migrations) {
            try {
              await db.execute(sql);
            } catch (_) {
              // Column likely exists
            }
          }
        },
      ),
    );
  }

  // ── Document Operations ──

  Future<void> insertDocument(Map<String, dynamic> doc) async {
    final db = await database;
    await db.insert('documents', doc, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return db.query('documents', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getDocument(String id) async {
    final db = await database;
    final results = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> hashExists(String hash) async {
    final db = await database;
    final results = await db.query('documents',
        where: 'md5_hash = ?', whereArgs: [hash], limit: 1);
    return results.isNotEmpty;
  }

  Future<Set<String>> getAllHashes() async {
    final db = await database;
    final results = await db.query('documents', columns: ['md5_hash']);
    return results.map((r) => r['md5_hash'] as String).toSet();
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    // Related chunks will be deleted automatically via ON DELETE CASCADE in SQL
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllDocuments() async {
    final db = await database;
    await db.delete('documents');
    await db.delete('chunks');
  }

  // ── Chunk Operations ──

  Future<void> insertChunks(String documentId, List<TextChunk> chunks) async {
    final db = await database;
    final batch = db.batch();

    for (final chunk in chunks) {
      // Generate simple TF-IDF vector for each chunk
      final tfidf = _computeTfIdf(chunk.content);

      batch.insert('chunks', {
        'document_id': documentId,
        'chunk_index': chunk.index,
        'content': chunk.content,
        'start_word': chunk.startWord,
        'end_word': chunk.endWord,
        'start_page': chunk.startPage,
        'end_page': chunk.endPage,
        'tfidf_vector': jsonEncode(tfidf),
      });
    }

    await batch.commit(noResult: true);

    // Update chunk count
    await db.update(
      'documents',
      {'chunk_count': chunks.length},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<List<Map<String, dynamic>>> getChunksForDocument(String documentId) async {
    final db = await database;
    return db.query('chunks',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'chunk_index ASC');
  }

  /// Semantic search: find most relevant chunks for a query across specific documents
  Future<List<RankedChunk>> searchChunks(
    String query, {
    List<String>? documentIds,
    int topK = 5,
  }) async {
    final db = await database;
    final queryVector = _computeTfIdf(query);

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (documentIds != null && documentIds.isNotEmpty) {
      final placeholders = documentIds.map((_) => '?').join(',');
      whereClause = 'WHERE document_id IN ($placeholders)';
      whereArgs = documentIds;
    }

    final chunks = await db.rawQuery(
      'SELECT * FROM chunks $whereClause ORDER BY chunk_index',
      whereArgs,
    );

    // Rank by cosine similarity
    final ranked = chunks.map((chunk) {
      final storedVector =
          Map<String, double>.from(jsonDecode(chunk['tfidf_vector'] as String));
      final similarity = _cosineSimilarity(queryVector, storedVector);

      return RankedChunk(
        documentId: chunk['document_id'] as String,
        chunkIndex: chunk['chunk_index'] as int,
        content: chunk['content'] as String,
        startPage: chunk['start_page'] as int?,
        endPage: chunk['end_page'] as int?,
        score: similarity,
      );
    }).toList();

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(topK).toList();
  }

  // ── TF-IDF & Similarity ──

  Map<String, double> _computeTfIdf(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final wordCount = <String, int>{};
    final total = words.length;

    for (final word in words) {
      if (word.length < 2) continue; // Skip single chars
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }

    // Simple TF normalization
    return wordCount.map((word, count) => MapEntry(word, count / total));
  }

  double _cosineSimilarity(
      Map<String, double> a, Map<String, double> b) {
    double dot = 0, normA = 0, normB = 0;
    final allKeys = {...a.keys, ...b.keys};

    for (final key in allKeys) {
      final va = a[key] ?? 0;
      final vb = b[key] ?? 0;
      dot += va * vb;
      normA += va * va;
      normB += vb * vb;
    }

    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class RankedChunk {
  final String documentId;
  final int chunkIndex;
  final String content;
  final int? startPage;
  final int? endPage;
  final double score;

  RankedChunk({
    required this.documentId,
    required this.chunkIndex,
    required this.content,
    this.startPage,
    this.endPage,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'chunkIndex': chunkIndex,
        'content': content,
        'startPage': startPage,
        'endPage': endPage,
        'score': score,
      };
}
