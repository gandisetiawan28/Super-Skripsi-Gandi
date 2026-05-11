import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'device_info_service.dart';

class LicenseValidationService {
  // ⬇️ TEMPEL URL WEB APP GOOGLE ANDA DI SINI ⬇️
  static const String _baseUrl = "https://script.google.com/macros/s/AKfycbzJg_yiBG1uLdL2E28T7XfRz0CR0qDYgMG2AzBH6J9kqQorZw7NCEMqzKXOVqCA8X1j/exec";
  static const String _secretToken = "SUPER_GANDI_SECURE_2024";

  final DeviceInfoService _deviceInfo = DeviceInfoService();
  static const String _securityBoxName = 'security_state';
  static const String _failedAttemptsKey = 'license_failed_attempts';
  static const String _lastAttemptTimeKey = 'license_last_failed_time';

  Future<Map<String, dynamic>> activate(String licenseKey) async {
    final blockStatus = await checkBlockStatus();
    if (blockStatus['is_blocked']) {
      return blockStatus;
    }

    try {
      final deviceId = await _deviceInfo.getUniqueId();
      final deviceName = await _deviceInfo.getDeviceName();

      var response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "token": _secretToken,
          "action": "activate",
          "license_key": licenseKey,
          "device_id": deviceId,
          "device_name": deviceName,
        }),
      );

      // Google Apps Script sering mengembalikan 302 Redirect pada POST request.
      // HTTP client Dart kadang tidak mengikutinya otomatis untuk POST.
      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body) as Map<String, dynamic>;
        // Pastikan status dan message tidak null
        result['status'] ??= 'error';
        result['message'] ??= 'Respons server tidak valid';
        
        if (result['status'] == 'success') {
          await _resetAttempts();
        } else {
          await _recordFailure();
        }
        return result;
      } else {
        await _recordFailure();
        return {"status": "error", "message": "Server Error: ${response.statusCode}"};
      }
    } catch (e) {
      return {"status": "error", "message": "Koneksi Gagal: ${e.toString()}"};
    }
  }

  /// Mengecek status lisensi yang sedang aktif (apakah masih Active atau sudah Blocked/Dihapus)
  Future<Map<String, dynamic>> validate(String licenseKey) async {
    try {
      final deviceId = await _deviceInfo.getUniqueId();
      
      var response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "token": _secretToken,
          "action": "validate", // Aksi baru di Google Apps Script untuk cek status
          "license_key": licenseKey,
          "device_id": deviceId,
        }),
      );

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body) as Map<String, dynamic>;
        result['status'] ??= 'error';
        return result;
      } else {
        return {"status": "error", "message": "Server Error"};
      }
    } catch (e) {
      return {"status": "error", "message": "Koneksi Gagal"};
    }
  }

  // ─── SECURITY LOGIC ──────────────────────────────────────────────────────

  Future<void> _recordFailure() async {
    final box = await Hive.openBox(_securityBoxName);
    int attempts = box.get(_failedAttemptsKey, defaultValue: 0);
    await box.put(_failedAttemptsKey, attempts + 1);
    await box.put(_lastAttemptTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _resetAttempts() async {
    final box = await Hive.openBox(_securityBoxName);
    await box.delete(_failedAttemptsKey);
    await box.delete(_lastAttemptTimeKey);
  }

  Future<Map<String, dynamic>> checkBlockStatus() async {
    final box = await Hive.openBox(_securityBoxName);
    final attempts = box.get(_failedAttemptsKey, defaultValue: 0);
    final lastTimeMillis = box.get(_lastAttemptTimeKey);

    if (attempts < 2 || lastTimeMillis == null) {
      return {"is_blocked": false};
    }

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
    final now = DateTime.now();
    
    int penaltySeconds = 0;
    if (attempts == 2) penaltySeconds = 30;
    else if (attempts == 3) penaltySeconds = 120;
    else if (attempts == 4) penaltySeconds = 600;
    else if (attempts >= 5) penaltySeconds = 3600;

    final unlockTime = lastTime.add(Duration(seconds: penaltySeconds));
    if (now.isBefore(unlockTime)) {
      final remaining = unlockTime.difference(now);
      return {
        "is_blocked": true,
        "status": "blocked",
        "message": "Terlalu banyak percobaan. Coba lagi dalam ${remaining.inMinutes} menit ${remaining.inSeconds % 60} detik.",
      };
    }

    return {"is_blocked": false};
  }

  /// Mengecek update aplikasi
  Future<Map<String, dynamic>> checkUpdate(String platform) async {
    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "token": _secretToken,
          "action": "check_update",
          "platform": platform,
        }),
      );

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {"status": "error"};
  }

  /// Mengirim hasil survey ke Spreadsheet
  Future<void> submitSurvey({
    required String name,
    required String email,
    required String source,
  }) async {
    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          "token": _secretToken,
          "action": "submit_survey",
          "name": name,
          "email": email,
          "source": source,
        }),
      );

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] != 'success') {
          throw Exception(result['message']);
        }
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Gagal mengirim survey: ${e.toString()}');
    }
  }
}
