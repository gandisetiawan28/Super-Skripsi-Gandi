import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/license_model.dart';
import 'device_info_service.dart';
import 'license_validation_service.dart';

class LicenseService {
  // Production Endpoint (Google Apps Script)
  static const String _apiEndpoint = 'https://script.google.com/macros/s/AKfycbzJg_yiBG1uLdL2E28T7XfRz0CR0qDYgMG2AzBH6J9kqQorZw7NCEMqzKXOVqCA8X1j/exec';
  static const String _boxName = 'license_store';
  static const String _sessionKey = 'current_session';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      final encryptionKey = await _getEncryptionKey();
      return await Hive.openBox(_boxName, encryptionCipher: HiveAesCipher(encryptionKey));
    }
    return Hive.box(_boxName);
  }

  Future<List<int>> _getEncryptionKey() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = 'license_id';
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      deviceId = windowsInfo.deviceId;
    }
    return sha256.convert(utf8.encode('skripsi_license_$deviceId')).bytes;
  }

  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final LicenseValidationService _remoteApi = LicenseValidationService();

  /// Memvalidasi lisensi ke Cloud (Google Sheets via Apps Script)
  Future<LicenseModel?> validateLicense(String licenseKey, String name) async {
    // ── Hardcoded Admin Bypass ──
    if (name == 'Gandi Setiawan' && licenseKey == '@Gandisetiawan') {
      final adminLicense = LicenseModel(
        userName: 'Gandi Setiawan',
        deviceId: 'admin_device',
        key: '@Gandisetiawan',
        status: 'aktif',
        expiryDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
        lastValidated: DateTime.now(),
      );
      await _cacheLicense(adminLicense);
      return adminLicense;
    }

    try {
      final result = await _remoteApi.activate(licenseKey);

      if (result['status'] == 'success') {
        final deviceId = await _deviceInfoService.getUniqueId();
        final license = LicenseModel(
          userName: name,
          deviceId: deviceId,
          key: licenseKey,
          status: 'aktif',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          lastValidated: DateTime.now(),
        );
        await _cacheLicense(license);
        return license;
      } else {
        // Lemparkan pesan error dari API agar muncul di UI
        throw Exception(result['message'] ?? 'Gagal memvalidasi lisensi.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('Koneksi Gagal')) {
        rethrow;
      }
      
      // Jika benar-benar offline (Koneksi Gagal), coba cek cache lokal
      final cached = await getCachedLicense();
      if (cached != null) return cached;
      
      // Jika tidak ada cache, tampilkan error asli agar tahu kenapa gagal
      throw Exception('Gagal menghubungi server. Info: ${e.toString().replaceAll("Exception: Koneksi Gagal:", "")}');
    }
  }

  /// Memvalidasi ulang lisensi yang sudah tersimpan (untuk Background Check)
  Future<bool> reValidateLicense(LicenseModel license) async {
    // Admin bypass
    if (license.key == '@Gandisetiawan') return true;

    try {
      final result = await _remoteApi.validate(license.key);
      
      // Jika status bukan 'success' atau status lisensi bukan 'Active', maka dianggap tidak valid
      if (result['status'] != 'success' || result['license_status'] != 'Active') {
        await clearLicense();
        return false;
      }
      
      // Update tanggal validasi terakhir di cache
      final updatedLicense = LicenseModel(
        userName: license.userName,
        deviceId: license.deviceId,
        key: license.key,
        status: 'aktif',
        expiryDate: license.expiryDate,
        lastValidated: DateTime.now(),
      );
      await _cacheLicense(updatedLicense);
      return true;
    } catch (e) {
      // Jika gagal koneksi, kita anggap masih valid (agar tidak logout saat internet mati sementara)
      return true; 
    }
  }

  /// Menyimpan sesi lisensi secara aman
  Future<void> _cacheLicense(LicenseModel license) async {
    final box = await _getBox();
    await box.put(_sessionKey, license.toJson());
  }

  /// Mengambil lisensi dari cache lokal (Offline Fallback)
  Future<LicenseModel?> getCachedLicense() async {
    final box = await _getBox();
    final data = box.get(_sessionKey);
    if (data != null) {
      final license = LicenseModel.fromJson(Map<String, dynamic>.from(data));
      // Still active?
      if (license.isActive) {
        return license;
      }
    }
    return null;
  }

  /// Menghapus sesi lisensi (Logout)
  Future<void> clearLicense() async {
    final box = await _getBox();
    await box.delete(_sessionKey);
  }
}
