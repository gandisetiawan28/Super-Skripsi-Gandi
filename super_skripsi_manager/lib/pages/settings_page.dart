import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../services/updater_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_service.dart';
import '../providers/license_provider.dart';
import '../providers/onboarding_provider.dart';
import '../services/device_info_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final UpdaterService _updater = UpdaterService();
  UpdateInfo? _updateInfo;
  bool _checkingUpdate = false;
  double _downloadProgress = 0;
  bool _downloading = false;

  late TextEditingController _nameController;
  String _deviceId = "Memuat...";
  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    _nameController = TextEditingController(text: state.googleName);
    _loadDeviceId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final id = await _deviceInfoService.getUniqueId();
    if (mounted) setState(() => _deviceId = id.substring(0, 16).toUpperCase());
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      await ref.read(onboardingProvider.notifier).updateProfile(
        photoPath: result.files.single.path,
      );
    }
  }

  void _saveName() {
    if (_nameController.text.trim().isNotEmpty) {
      ref.read(onboardingProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await _updater.checkForUpdate();
      setState(() => _updateInfo = info);

      if (info == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aplikasi sudah versi terbaru!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: GlassmorphismTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _checkingUpdate = false);
  }

  Future<void> _downloadAndInstall() async {
    if (_updateInfo == null || !_updateInfo!.hasInstaller) return;

    setState(() => _downloading = true);
    try {
      final path = await _updater.downloadUpdate(
        _updateInfo!.downloadUrl!,
        _updateInfo!.assetName!,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      if (path != null) {
        await _updater.executeInstaller(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingState>(onboardingProvider, (previous, next) {
      if (next.googleName != null && _nameController.text != next.googleName) {
        _nameController.text = next.googleName!;
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildProfileSection(),
          const SizedBox(height: 24),

          // App Info
          GlassCard(
            margin: EdgeInsets.zero,
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GlassmorphismTheme.primaryRed,
                            GlassmorphismTheme.primaryRedLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Super Skripsi Gandi Manager',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Version 1.0.0',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: GlassmorphismTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Auto-Updater
          GlassCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Updater',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Periksa pembaruan terbaru dari GitHub Releases.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: GlassmorphismTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                if (_updateInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GlassmorphismTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update tersedia: v${_updateInfo!.latestVersion}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: GlassmorphismTheme.info,
                          ),
                        ),
                        if (_updateInfo!.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _updateInfo!.releaseNotes,
                            style: GoogleFonts.inter(fontSize: 12),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_downloading) ...[
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor:
                          GlassmorphismTheme.primaryRed.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                          GlassmorphismTheme.primaryRed),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _downloadAndInstall,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download & Install'),
                    ),
                ] else
                  ElevatedButton.icon(
                    onPressed: _checkingUpdate ? null : _checkForUpdates,
                    icon: _checkingUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                        _checkingUpdate ? 'Memeriksa...' : 'Cek Pembaruan'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout
          GlassCard(
            margin: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lisensi',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Logout akan menghapus sesi sinkronisasi Google Drive.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Sign out dari Google agar harus login ulang
                    try {
                      await ref.read(googleSignInProvider).signOut();
                    } catch (e) {
                      debugPrint('Error signing out from Google: $e');
                    }
                    
                    ref.read(syncProvider.notifier).clearMetadata();
                    // ref.read(licenseStateProvider.notifier).logout(); // Opsi 2: Lisensi menempel di hardware
                    ref.read(onboardingProvider.notifier).resetOnboarding();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassmorphismTheme.error,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final state = ref.watch(onboardingProvider);
    
    return GlassCard(
      margin: EdgeInsets.zero,
      elevated: true,
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                    backgroundImage: state.customPhotoPath != null
                        ? FileImage(File(state.customPhotoPath!))
                        : (state.googlePhotoUrl != null ? NetworkImage(state.googlePhotoUrl!) : null) as ImageProvider?,
                    child: (state.customPhotoPath == null && state.googlePhotoUrl == null)
                        ? Text(
                            (state.googleName ?? "U").substring(0, 1).toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: GlassmorphismTheme.primaryRed,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: GlassmorphismTheme.primaryRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            onChanged: (_) => _saveName(),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Nama Anda',
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_rounded, size: 16, color: GlassmorphismTheme.textSecondary),
                      ],
                    ),
                    Text(
                      state.googleEmail ?? 'Tidak ada email',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.devices_rounded, size: 12, color: GlassmorphismTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Device ID: $_deviceId',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              color: GlassmorphismTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
