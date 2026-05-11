import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Mengambil ID unik perangkat dan di-hash (SHA-256) untuk keamanan
  Future<String> getUniqueId() async {
    // Coba ambil dari cache Hive dulu agar stabil
    final box = await Hive.openBox('device_settings');
    final cachedId = box.get('persistent_device_id');
    if (cachedId != null) return cachedId as String;

    String rawId = "";

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        rawId = "${webInfo.vendor}${webInfo.userAgent}${webInfo.hardwareConcurrency}";
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        rawId = windowsInfo.deviceId;
      } else if (Platform.isAndroid) {
        // Proteksi ekstra untuk bug di device_info_plus pada Android API 36
        try {
          final androidInfo = await _deviceInfo.androidInfo;
          rawId = androidInfo.id;
        } catch (e) {
          debugPrint("⚠️ Gagal mengambil Android ID: $e");
          rawId = "android_fallback";
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? "ios_unknown";
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        rawId = macInfo.systemGUID ?? "macos_unknown";
      }
      
      // Jika masih kosong (beberapa emulator Android ID-nya kosong/gagal)
      if (rawId.isEmpty || rawId == "unknown" || rawId == "android_fallback") {
        rawId = "fallback_${DateTime.now().millisecondsSinceEpoch}";
      }
    } catch (e) {
      rawId = "fallback_${DateTime.now().millisecondsSinceEpoch}";
    }

    // Hash menggunakan SHA-256 agar privasi terjaga
    var bytes = utf8.encode(rawId);
    var digest = sha256.convert(bytes).toString();
    
    // Simpan ke cache agar tidak berubah lagi
    await box.put('persistent_device_id', digest);
    return digest;
  }

  /// Mengambil nama perangkat manusiawi (misal: "Windows - GANDI-PC")
  Future<String> getDeviceName() async {
    try {
      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return "Windows - ${info.computerName}";
      } else if (Platform.isAndroid) {
        try {
          final info = await _deviceInfo.androidInfo;
          return "Android - ${info.model}";
        } catch (e) {
          return "Android Device";
        }
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return "iOS - ${info.name}";
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }
}
