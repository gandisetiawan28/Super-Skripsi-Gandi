import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';
import '../providers/license_provider.dart';

class LicenseGatePage extends ConsumerStatefulWidget {
  final VoidCallback onLicenseValid;

  const LicenseGatePage({super.key, required this.onLicenseValid});

  @override
  ConsumerState<LicenseGatePage> createState() => _LicenseGatePageState();
}

class _LicenseGatePageState extends ConsumerState<LicenseGatePage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final licenseState = ref.watch(licenseStateProvider);
    final blockStatus = ref.watch(licenseBlockTimerProvider).value ?? {"is_blocked": false};
    final bool isBlocked = blockStatus['is_blocked'] ?? false;
    final String blockMessage = blockStatus['message'] ?? '';

    // Auto-redirect if cached license is valid
    ref.listen<AsyncValue<dynamic>>(licenseStateProvider, (prev, next) {
      next.whenData((license) {
        if (license != null && license.isActive) {
          widget.onLicenseValid();
        }
      });
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlassmorphismTheme.backgroundStart,
              GlassmorphismTheme.backgroundEnd,
              Color(0xFFFCE4EC), // Faint red tint
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GlassmorphismTheme.radiusXL),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius:
                        BorderRadius.circular(GlassmorphismTheme.radiusXL),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1,
                    ),
                    boxShadow: GlassmorphismTheme.elevatedShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GlassmorphismTheme.primaryRed,
                              GlassmorphismTheme.primaryRedLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow:
                              GlassmorphismTheme.redGlowShadow,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Super Skripsi Gandi',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: GlassmorphismTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Masukkan lisensi untuk melanjutkan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: GlassmorphismTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Name field
                      TextField(
                        controller: _nameController,
                        enabled: !isBlocked,
                        decoration: const InputDecoration(
                          labelText: 'Nama',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // License key field
                      TextField(
                        controller: _keyController,
                        enabled: !isBlocked,
                        decoration: const InputDecoration(
                          labelText: 'Kode Lisensi',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Validate button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (licenseState.isLoading || isBlocked)
                              ? null
                              : () {
                                  ref
                                      .read(licenseStateProvider.notifier)
                                      .validate(
                                        name: _nameController.text.trim(),
                                        key: _keyController.text.trim(),
                                      );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isBlocked 
                                ? Colors.grey 
                                : GlassmorphismTheme.primaryRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  GlassmorphismTheme.radiusMedium),
                            ),
                          ),
                          child: licenseState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isBlocked ? 'Terkunci (Anti-Spam)' : 'Validasi Lisensi',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      // Error display or Block message
                      Builder(
                        builder: (context) {
                          if (isBlocked) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                blockMessage,
                                style: TextStyle(
                                  color: GlassmorphismTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          
                          return licenseState.whenOrNull(
                                error: (e, _) => Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    e.toString().replaceAll("Exception: ", ""),
                                    style: TextStyle(
                                      color: GlassmorphismTheme.error,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                data: (license) {
                                  if (license != null && !license.isActive) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: const Text(
                                        'Lisensi tidak aktif. Hubungi admin.',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return null;
                                },
                              ) ??
                              const SizedBox.shrink();
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
