import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'api_key_service.dart';
import 'vector_store_service.dart';
import '../constants/app_constants.dart';

typedef LogCallback = void Function(String level, String message);

class LocalServerService {
  static const int defaultPort = 28145;
  HttpServer? _server;
  final ApiKeyService _apiKeyService;
  final VectorStoreService _vectorStore;
  LogCallback? onLog;

  int get port => _server?.port ?? defaultPort;
  bool get isRunning => _server != null;

  LocalServerService(this._apiKeyService, this._vectorStore);

  /// Start the local HTTP server
  Future<void> start({int port = defaultPort}) async {
    if (_server != null) {
      _log('warn', 'Server already running on port ${_server!.port}');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _log('info', '🚀 Local server started on http://localhost:$port');

      _server!.listen(
        _handleRequest,
        onError: (e) => _log('error', 'Server error: $e'),
      );
    } catch (e) {
      _log('error', 'Failed to start server on port $port: $e');
      rethrow;
    }
  }

  /// Stop the server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _log('info', '⏹ Server stopped');
  }

  void _log(String level, String message) {
    onLog?.call(level, '[${DateTime.now().toIso8601String()}] $message');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // ── CORS Headers ──
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..add('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      ..add('Content-Type', 'application/json; charset=utf-8');

    // Handle preflight OPTIONS
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    _log('info', '${request.method} $path');

    try {
      if (path == '/api/health') {
        await _handleHealth(request);
      } else if (path == '/api/keys') {
        await _handleKeys(request);
      } else if (path == '/api/documents') {
        await _handleDocuments(request);
      } else if (RegExp(r'^/api/documents/[^/]+/chunks$').hasMatch(path)) {
        await _handleDocumentChunks(request);
      } else if (RegExp(r'^/api/documents/[^/]+/context$').hasMatch(path)) {
        await _handleDocumentContext(request);
      } else if (path == '/api/search') {
        await _handleSearch(request);
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({
          'error': 'Not found',
          'availableEndpoints': [
            '/api/health',
            '/api/keys',
            '/api/documents',
            '/api/documents/{id}/chunks',
            '/api/documents/{id}/context',
            '/api/search?q=query&docs=id1,id2',
          ]
        }));
      }
    } catch (e) {
      _log('error', 'Request error: $e');
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
    }

    await request.response.close();
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.write(jsonEncode({
      'status': 'ok',
      'server': 'Super Skripsi Gandi Manager',
      'version': AppConstants.currentVersion,
      'port': port,
      'uptime': DateTime.now().toIso8601String(),
    }));
  }

  Future<void> _handleKeys(HttpRequest request) async {
    final keysMap = await _apiKeyService.getAllKeysMap();
    
    // Flatten result for the Add-in (only send the actual keys)
    final flattenedKeys = <String, List<String>>{};
    keysMap.forEach((provider, items) {
      flattenedKeys[provider] = items.map((item) => item['key'] ?? '').toList();
    });

    request.response.write(jsonEncode({
      'keys': flattenedKeys,
      'providers': flattenedKeys.keys.toList(),
    }));
  }

  Future<void> _handleDocuments(HttpRequest request) async {
    final docs = await _vectorStore.getAllDocuments();
    final metadataList = docs.map((d) {
      return {
        'id': d['id'],
        'originalFileName': d['original_filename'],
        'renamedFileName': d['renamed_filename'],
        'title': d['title'],
        'authors': jsonDecode(d['authors'] as String),
        'year': d['year'],
        'category': d['category'],
        'chunkCount': d['chunk_count'],
        'createdAt': d['created_at'],
      };
    }).toList();

    request.response.write(jsonEncode({'documents': metadataList}));
  }

  Future<void> _handleDocumentChunks(HttpRequest request) async {
    final id = request.uri.pathSegments[2];
    final chunks = await _vectorStore.getChunksForDocument(id);
    request.response.write(jsonEncode({
      'documentId': id,
      'chunks': chunks
          .map((c) => {
                'index': c['chunk_index'],
                'content': c['content'],
                'startPage': c['start_page'],
                'endPage': c['end_page'],
              })
          .toList(),
    }));
  }

  Future<void> _handleDocumentContext(HttpRequest request) async {
    final id = request.uri.pathSegments[2];
    final doc = await _vectorStore.getDocument(id);
    if (doc == null) {
      request.response.statusCode = 404;
      request.response.write(jsonEncode({'error': 'Document not found'}));
      return;
    }

    request.response.write(jsonEncode({
      'id': doc['id'],
      'title': doc['title'],
      'authors': jsonDecode(doc['authors'] as String),
      'year': doc['year'],
      'textContent': doc['text_content'],
    }));
  }

  Future<void> _handleSearch(HttpRequest request) async {
    final query = request.uri.queryParameters['q'];
    final docIds = request.uri.queryParameters['docs']?.split(',');

    if (query == null || query.isEmpty) {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({'error': 'Query parameter "q" is required'}));
      return;
    }

    final results = await _vectorStore.searchChunks(
      query,
      documentIds: docIds,
      topK: 8,
    );

    request.response.write(jsonEncode({
      'query': query,
      'results': results.map((r) => r.toJson()).toList(),
    }));
  }
}
