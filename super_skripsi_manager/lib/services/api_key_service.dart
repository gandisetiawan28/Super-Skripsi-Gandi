import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import '../utils/session_utils.dart';

class ApiKeyService {
  final String? _userEmail;
  static const String _boxBaseName = 'secure_settings';
  static const String _keysKey = 'api_keys';
  
  ApiKeyService(this._userEmail);
  
  // Hive doesn't need native compilation for Windows, making it more stable
  // with paths containing spaces.
  
  Future<Box> _getBox() async {
    final boxName = SessionUtils.getDynamicBoxName(_boxBaseName, _userEmail);
    if (!Hive.isBoxOpen(boxName)) {
      // Use a machine-specific key for encryption
      final encryptionKey = await _getEncryptionKey();
      return await Hive.openBox(boxName, encryptionCipher: HiveAesCipher(encryptionKey));
    }
    return Hive.box(boxName);
  }

  Future<List<int>> _getEncryptionKey() async {
    // Generate a stable key based on device info
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = 'default_id';
    
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      deviceId = windowsInfo.deviceId;
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      deviceId = macInfo.systemGUID ?? 'macos';
    }
    
    // Hash the device ID to get a 32-byte key for AES
    final key = sha256.convert(utf8.encode('super_skripsi_gandi_$deviceId')).bytes;
    return key;
  }

  Future<void> saveKey(String provider, String name, String apiKey) async {
    final box = await _getBox();
    final keys = await getAllKeysMap();
    
    if (!keys.containsKey(provider)) {
      keys[provider] = [];
    }
    
    // Add as an object with name and key
    keys[provider]!.add({
      'name': name.isEmpty ? 'Key #${keys[provider]!.length + 1}' : name,
      'key': apiKey,
    });
    
    await box.put(_keysKey, keys);
  }

  Future<List<Map<String, String>>> getKeys(String provider) async {
    final keys = await getAllKeysMap();
    return keys[provider] ?? [];
  }

  Future<Map<String, List<Map<String, String>>>> getAllKeysMap() async {
    final box = await _getBox();
    final data = box.get(_keysKey);
    if (data == null) return {};
    
    if (data is Map) {
      final result = <String, List<Map<String, String>>>{};
      data.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((v) {
            if (v is Map) {
              return Map<String, String>.from(v);
            } else if (v is String) {
              // Migration: convert old strings to objects
              return {'name': 'Legacy Key', 'key': v};
            }
            return {'name': 'Unknown', 'key': ''};
          }).toList();
        } else if (value is String) {
          // Migration from very old single string
          result[key.toString()] = [{'name': 'Primary Key', 'key': value}];
        }
      });
      return result;
    }
    return {};
  }

  Future<void> deleteKey(String provider, int index) async {
    final box = await _getBox();
    final keys = await getAllKeysMap();
    if (keys.containsKey(provider)) {
      if (index >= 0 && index < keys[provider]!.length) {
        keys[provider]!.removeAt(index);
        if (keys[provider]!.isEmpty) {
          keys.remove(provider);
        }
        await box.put(_keysKey, keys);
      }
    }
  }

  Future<void> deleteProvider(String provider) async {
    final box = await _getBox();
    final keys = await getAllKeysMap();
    keys.remove(provider);
    await box.put(_keysKey, keys);
  }

  Future<void> clearAll() async {
    final box = await _getBox();
    await box.delete(_keysKey);
  }

  Future<void> seedDefaults() async {
    await fixBadUrls(); 
    final keys = await getAllKeysMap();
    
    // Hapus CORE API (Legacy) jika masih ada
    if (keys.containsKey('CORE API')) {
      await deleteProvider('CORE API');
    }

    // Seed Localhost
    if (!keys.containsKey('Localhost') || keys['Localhost']!.isEmpty) {
      await saveKey('Localhost', 'Gemini Flow (Default)', 'http://127.0.0.1:3000');
    }
  }

  Future<void> fixBadUrls() async {
    final box = await _getBox();
    final keys = await getAllKeysMap();
    bool modified = false;

    if (keys.containsKey('Localhost')) {
      for (var keyObj in keys['Localhost']!) {
        String url = keyObj['key'] ?? '';
        String original = url;

        // 1. Migrate localhost to 127.0.0.1
        if (url.contains('localhost:3000')) {
          url = url.replaceAll('localhost:3000', '127.0.0.1:3000');
        }

        // 2. Clean up trailing /api or /
        if (url.contains('/api') || url.endsWith('/')) {
          while (url.endsWith('/api') || url.endsWith('/')) {
             url = url.replaceAll(RegExp(r'\/+$'), '');
             if (url.endsWith('/api')) {
                url = url.substring(0, url.length - 4);
             }
          }
        }

        if (original != url) {
          keyObj['key'] = url;
          modified = true;
        }
      }
    }

    if (modified) {
      await box.put(_keysKey, keys);
      print('🛠️ Database: Berhasil membersihkan URL Localhost yang ganda.');
    }
  }
}
