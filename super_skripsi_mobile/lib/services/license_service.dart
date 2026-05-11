import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/license_model.dart';
import 'device_info_service.dart';
import 'license_validation_service.dart';

class LicenseService {
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
    // Gunakan DeviceInfoService yang aman bukannya memanggil DeviceInfoPlugin langsung
    final deviceId = await _deviceInfoService.getUniqueId();
    return sha256.convert(utf8.encode('skripsi_license_$deviceId')).bytes;
  }

  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final LicenseValidationService _remoteApi = LicenseValidationService();

  /// Memvalidasi lisensi ke Cloud (Google Sheets via Apps Script)
  Future<LicenseModel?> validateLicense(String licenseKey, String name) async {
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
        throw Exception(result['message'] ?? 'Gagal memvalidasi lisensi.');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('Koneksi Gagal')) {
        rethrow;
      }
      
      final cached = await getCachedLicense();
      if (cached != null) return cached;
      
      throw Exception('Gagal menghubungi server. Info: ${e.toString().replaceAll("Exception: Koneksi Gagal:", "")}');
    }
  }

  /// Memvalidasi ulang lisensi yang sudah tersimpan
  Future<bool> reValidateLicense(LicenseModel license) async {
    try {
      final result = await _remoteApi.validate(license.key);
      
      if (result['status'] != 'success' || result['license_status'] != 'Active') {
        await clearLicense();
        return false;
      }
      
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
      return true; 
    }
  }

  Future<void> _cacheLicense(LicenseModel license) async {
    final box = await _getBox();
    await box.put(_sessionKey, license.toJson());
  }

  Future<LicenseModel?> getCachedLicense() async {
    final box = await _getBox();
    final data = box.get(_sessionKey);
    if (data != null) {
      final license = LicenseModel.fromJson(Map<String, dynamic>.from(data));
      if (license.isActive) {
        return license;
      }
    }
    return null;
  }

  Future<void> clearLicense() async {
    final box = await _getBox();
    await box.delete(_sessionKey);
  }
}
