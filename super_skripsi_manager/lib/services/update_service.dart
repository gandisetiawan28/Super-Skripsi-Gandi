import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'license_validation_service.dart';

class UpdateService {
  final LicenseValidationService _api = LicenseValidationService();

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      String platform = "Windows";
      if (Platform.isAndroid) platform = "Android";
      
      final result = await _api.checkUpdate(platform);
      
      if (result["status"] == "success") {
        final String latestVersion = result["latest_version"];
        final String downloadUrl = result["download_url"];
        final bool forceUpdate = result["force_update"] ?? false;

        if (_isVersionNewer(currentVersion, latestVersion)) {
          _showUpdateDialog(context, latestVersion, downloadUrl, forceUpdate);
        }
      }
    } catch (_) {}
  }

  bool _isVersionNewer(String current, String latest) {
    List<int> currParts = current.split('.').map(int.parse).toList();
    List<int> lateParts = latest.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (lateParts[i] > currParts[i]) return true;
      if (lateParts[i] < currParts[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url, bool force) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (context) => AlertDialog(
        title: const Text("🚀 Pembaruan Tersedia"),
        content: Text("Versi terbaru ($version) sudah tersedia. Silakan unduh untuk mendapatkan fitur dan perbaikan terbaru."),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Nanti Saja"),
            ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(url)),
            child: const Text("Unduh Sekarang"),
          ),
        ],
      ),
    );
  }
}
