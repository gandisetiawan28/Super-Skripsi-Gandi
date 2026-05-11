import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _masterKeyName = 'super_skripsi_master_key';

  /// Get or generate a stable encryption key for Hive
  static Future<List<int>> getHiveEncryptionKey() async {
    String? base64Key = await _storage.read(key: _masterKeyName);

    if (base64Key == null) {
      // Generate a new random 256-bit key (32 bytes)
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      base64Key = base64Encode(values);
      
      await _storage.write(key: _masterKeyName, value: base64Key);
    }

    return base64Decode(base64Key);
  }

  /// Optional: Clear everything (Logout total)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
