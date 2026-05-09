import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Mengambil ID unik perangkat dan di-hash (SHA-256) untuk keamanan
  Future<String> getUniqueId() async {
    String rawId = "";

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        rawId = "${webInfo.vendor}${webInfo.userAgent}${webInfo.hardwareConcurrency}";
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        // deviceId di Windows mengambil Machine GUID dari Registry (Sangat Unik)
        rawId = windowsInfo.deviceId;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        rawId = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? "ios_unknown";
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        rawId = macInfo.systemGUID ?? "macos_unknown";
      }
    } catch (e) {
      rawId = "unknown_device_${DateTime.now().millisecondsSinceEpoch}";
    }

    // Hash menggunakan SHA-256 agar privasi terjaga
    var bytes = utf8.encode(rawId);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Mengambil nama perangkat manusiawi (misal: "Windows - GANDI-PC")
  Future<String> getDeviceName() async {
    try {
      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return "Windows - ${info.computerName}";
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return "Android - ${info.model}";
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return "iOS - ${info.name}";
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }
}
