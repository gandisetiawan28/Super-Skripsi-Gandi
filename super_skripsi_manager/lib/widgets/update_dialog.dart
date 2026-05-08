import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../services/updater_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final Function(String, String, Function(double)) onDownload;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onDownload,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;

  void _startUpdate() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      await widget.onDownload(
        widget.updateInfo.downloadUrl!,
        widget.updateInfo.assetName!,
        (p) => setState(() => _progress = p),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update Gagal: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GlassmorphismTheme.primaryRed.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 48,
                  color: GlassmorphismTheme.primaryRed,
                ),
              ),
              const SizedBox(height: 24),
              
              // Version Info
              Text(
                'Update Baru Tersedia!',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi ${widget.updateInfo.latestVersion} (Sekarang: ${widget.updateInfo.currentVersion})',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: GlassmorphismTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Release Notes Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apa yang baru:',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.updateInfo.releaseNotes,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              if (_isDownloading) ...[
                // Progress Bar
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(GlassmorphismTheme.primaryRed),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mendownload Update... ${(_progress * 100).toInt()}%',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ] else ...[
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Nanti Saja',
                          style: GoogleFonts.inter(color: GlassmorphismTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlassmorphismTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Update Sekarang'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
