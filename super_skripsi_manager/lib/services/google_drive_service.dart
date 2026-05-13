import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'secure_storage_service.dart';
import 'api_config.dart';
import '../constants/auth_html.dart';

final googleSignInProvider = Provider<auth.GoogleSignIn>((ref) => auth.GoogleSignIn(
  params: auth.GoogleSignInParams(
    clientId: ApiConfig.googleClientId,
    clientSecret: ApiConfig.googleClientSecret,
    scopes: ApiConfig.googleScopes,
    customPostAuthPage: authSuccessHtml,
  ),
));

class GoogleDriveService {
  final auth.GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;

  GoogleDriveService(this._googleSignIn);

  static const String _sessionBoxName = 'secure_session';

  Future<Box> _getBox() async {
    final encryptionKey = await SecureStorageService.getHiveEncryptionKey();
    return await Hive.openBox(_sessionBoxName, encryptionCipher: HiveAesCipher(encryptionKey));
  }

  Future<void> _saveSession(auth.GoogleSignInCredentials data) async {
    final box = await _getBox();
    await box.put('accessToken', data.accessToken);
    
    // Crucial: Only overwrite if we get a new refresh token.
    // Google often doesn't send it on subsequent logins.
    if (data.refreshToken != null && data.refreshToken!.isNotEmpty) {
      await box.put('refreshToken', data.refreshToken);
      print('✅ Refresh Token baru disimpan secara aman.');
    }
    
    print('✅ Sesi Google (Access Token) diperbarui.');
  }

  Future<auth.GoogleSignInCredentials?> _loadSession() async {
    final box = await _getBox();
    final accessToken = box.get('accessToken');
    final refreshToken = box.get('refreshToken');
    
    if (accessToken == null) return null;

    return auth.GoogleSignInCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Memulihkan sesi tanpa interaksi user (Silent Login)
  Future<bool> restoreSession() async {
    final saved = await _loadSession();
    if (saved == null) return false;

    // 1. Coba gunakan token yang ada (mungkin masih valid)
    _initApiWithCredentials(saved);
    
    try {
      // Verifikasi apakah token masih valid dengan list file singkat
      final res = await _driveApi!.files.list(pageSize: 1, $fields: 'files(id)');
      if (res.files != null) {
        print('✅ Sesi Google masih valid.');
        return true;
      }
    } catch (e) {
      print('⏳ Token lama kadaluarsa, mencoba Silent Refresh...');
      
      // 2. Jika gagal dan ada refreshToken, coba tukar dengan accessToken baru
      if (saved.refreshToken != null) {
        final newCredentials = await _refreshAccessToken(saved.refreshToken!);
        if (newCredentials != null) {
          await _saveSession(newCredentials);
          _initApiWithCredentials(newCredentials);
          print('✅ Sesi Google berhasil diperbarui secara otomatis.');
          return true;
        }
      }
      
      // 3. Jika refresh gagal, baru minta login interaktif
      // (Hanya jika benar-benar diperlukan)
      print('⚠️ Silent refresh gagal, meminta login interaktif...');
      final credentials = await _googleSignIn.signIn();
      if (credentials != null) {
        await _saveSession(credentials);
        _initApiWithCredentials(credentials);
        return true;
      }
    }

    return false;
  }

  /// Menukar Refresh Token dengan Access Token baru tanpa membuka browser
  Future<auth.GoogleSignInCredentials?> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': ApiConfig.googleClientId,
          'client_secret': ApiConfig.googleClientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return auth.GoogleSignInCredentials(
          accessToken: data['access_token'],
          refreshToken: refreshToken, // Simpan kembali refresh token yang sama
        );
      } else {
        print('❌ Gagal refresh token: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error saat refresh token: $e');
      return null;
    }
  }

  /// Logout total dan hapus semua sesi
  Future<void> signOut() async {
    try {
      // 1. Hapus data di Hive (Token & Session)
      final box = await _getBox();
      await box.clear();
      
      // 2. Sign out dari Google (All Platforms)
      await _googleSignIn.signOut();
      
      // 3. Reset internal state
      _driveApi = null;
      
      print('✅ Logout berhasil dan sesi dibersihkan.');
    } catch (e) {
      print('❌ Error saat logout: $e');
    }
  }

  void _initApiWithCredentials(auth.GoogleSignInCredentials credentials) {
    final authHeaders = {
      'Authorization': 'Bearer ${credentials.accessToken}',
    };
    final authenticateClient = _GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(authenticateClient);
    print('✅ API Google Drive dipulihkan dari sesi lokal.');
  }

  Future<bool> _initApi() async {
    if (_driveApi != null) return true;

    try {
      // Coba restore dulu
      if (await restoreSession()) return true;

      // Jika gagal restore, baru panggil interaktif
      final credentials = await _googleSignIn.signIn();
      if (credentials == null || credentials.accessToken == null) {
        print('Google Drive Error: Gagal mendapatkan token login.');
        return false;
      }

      await _saveSession(credentials);
      _initApiWithCredentials(credentials);
      return true;
    } catch (e) {
      print('Google Drive Init Error: $e');
      _driveApi = null; 
      return false;
    }
  }

  /// Upload file ke folder AppData di Google Drive
  Future<String?> uploadFile(File file, {String? driveFileId}) async {
    if (!await _initApi()) return null;

    final fileName = p.basename(file.path);
    final media = drive.Media(file.openRead(), file.lengthSync());
    
    final driveFile = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    try {
      drive.File response;
      if (driveFileId != null) {
        // Update existing file
        response = await _driveApi!.files.update(
          drive.File()..name = fileName,
          driveFileId,
          uploadMedia: media,
        );
      } else {
        // Create new file
        response = await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return response.id;
    } catch (e) {
      print('Google Drive Upload Error: $e');
      if (e.toString().contains('401')) {
        await _googleSignIn.signOut(); // Hapus token kadaluarsa
      }
      _driveApi = null; // Reset on error
      return null;
    }
  }

  /// List file di AppData folder
  Future<List<drive.File>> listAppDataFiles() async {
    if (!await _initApi()) return [];

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime, size)',
      );
      return fileList.files ?? [];
    } catch (e) {
      print('Google Drive List Error: $e');
      if (e.toString().contains('401')) {
        await _googleSignIn.signOut();
        final box = await _getBox();
        await box.clear(); // Hapus sesi bermasalah
      }
      _driveApi = null; 
      return [];
    }
  }

  /// Download file dari Drive
  Future<bool> downloadFile(String fileId, File targetFile) async {
    if (!await _initApi()) return false;

    try {
      final drive.Media response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await response.stream.listen((data) {
        dataBytes.addAll(data);
      }).asFuture();

      await targetFile.writeAsBytes(dataBytes);
      return true;
    } catch (e) {
      print('Google Drive Download Error: $e');
      return false;
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService(ref.watch(googleSignInProvider));
});
