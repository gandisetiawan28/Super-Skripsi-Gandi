import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class UpdaterService {
  // Placeholder — user sets their own repo
  static const String _defaultOwner = 'YOUR_GITHUB_USERNAME';
  static const String _defaultRepo = 'super-skripsi-gandi';
  static const String _currentVersion = '1.0.0';

  String _owner = _defaultOwner;
  String _repo = _defaultRepo;

  void configure({required String owner, required String repo}) {
    _owner = owner;
    _repo = repo;
  }

  /// Check GitHub for latest release
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String).replaceAll('v', '');
        final isNewer = _isNewerVersion(tagName, _currentVersion);

        if (isNewer) {
          // Find Windows installer asset
          final assets = data['assets'] as List<dynamic>? ?? [];
          String? downloadUrl;
          String? assetName;

          for (final asset in assets) {
            final name = asset['name'] as String;
            if (name.endsWith('.exe') || name.endsWith('.msix')) {
              downloadUrl = asset['browser_download_url'] as String;
              assetName = name;
              break;
            }
          }

          return UpdateInfo(
            currentVersion: _currentVersion,
            latestVersion: tagName,
            downloadUrl: downloadUrl,
            assetName: assetName,
            releaseNotes: data['body'] as String? ?? '',
            publishedAt: data['published_at'] as String? ?? '',
          );
        }
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        // Rate limited
        throw RateLimitException(
          'GitHub API rate limit exceeded. Try again later.',
        );
      }

      return null; // No update available
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw Exception('Failed to check for updates: $e');
    }
  }

  /// Download installer to temp directory
  Future<String?> downloadUpdate(
    String downloadUrl,
    String assetName, {
    Function(double)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, assetName);
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.close();
      client.close();

      return filePath;
    } catch (e) {
      throw Exception('Failed to download update: $e');
    }
  }

  /// Execute installer
  Future<void> executeInstaller(String filePath) async {
    if (filePath.endsWith('.exe')) {
      await Process.start(filePath, [], mode: ProcessStartMode.detached);
    } else if (filePath.endsWith('.msix')) {
      await launchUrl(Uri.file(filePath));
    }
  }

  /// Compare semantic versions: returns true if remote > local
  bool _isNewerVersion(String remote, String local) {
    final r = remote.split('.').map(int.tryParse).toList();
    final l = local.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final rv = (i < r.length ? r[i] : 0) ?? 0;
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String? downloadUrl;
  final String? assetName;
  final String releaseNotes;
  final String publishedAt;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.downloadUrl,
    this.assetName,
    required this.releaseNotes,
    required this.publishedAt,
  });

  bool get hasInstaller => downloadUrl != null && assetName != null;
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}
