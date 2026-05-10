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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: GlassmorphismTheme.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header / App Bar-like structure
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: GlassmorphismTheme.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Software Update',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: GlassmorphismTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (!_isDownloading)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: GlassmorphismTheme.textSecondary),
                    ),
                ],
              ),
              const Divider(height: 32, color: Colors.black12),
              const SizedBox(height: 16),
              
              // Version Info
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Versi baru tersedia: ${widget.updateInfo.latestVersion}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: GlassmorphismTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versi terinstal: ${widget.updateInfo.currentVersion}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Release Notes Box (Scrollable)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APA YANG BARU:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          widget.updateInfo.releaseNotes,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: GlassmorphismTheme.textPrimary.withOpacity(0.8),
                            height: 1.6,
                          ),
                        ),
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
                        value: _progress < 0 ? null : _progress,
                        minHeight: 10,
                        backgroundColor: Colors.black.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation(GlassmorphismTheme.primaryRed),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _progress < 0 
                        ? 'Menghubungkan ke server...' 
                        : 'Mendownload Update... ${(_progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 13, 
                        fontWeight: FontWeight.w500,
                        color: GlassmorphismTheme.textSecondary
                      ),
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
