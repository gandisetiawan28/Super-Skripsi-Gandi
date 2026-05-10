import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as auth;
import '../theme/glassmorphism_theme.dart';
import '../providers/onboarding_provider.dart';
import '../providers/license_provider.dart';
import '../services/sync_service.dart';
import '../services/google_drive_service.dart';
import '../services/updater_service.dart';
import '../widgets/update_dialog.dart';
import '../services/device_info_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class OnboardingPage extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingPage({super.key, required this.onCompleted});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _deviceId = "Memuat ID...";
  bool _isCompleting = false;
  bool _isGoogleLoading = false;
  bool _isInitialSyncDone = false;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadDeviceInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdates();
    });
  }

  Future<void> _loadDeviceInfo() async {
    final id = await DeviceInfoService().getUniqueId();
    if (mounted) {
      setState(() {
        // Ambil 8 karakter pertama saja agar tidak terlalu panjang di UI
        _deviceId = id.substring(0, 8).toUpperCase();
      });
    }
  }

  Future<void> _checkUpdates() async {
    final updater = UpdaterService();
    try {
      final info = await updater.checkForUpdate();
      if (info != null && info.hasInstaller && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            updateInfo: info,
            onDownload: (url, name, progress) async {
              final path = await updater.downloadUpdate(url, name, onProgress: progress);
              if (path != null) {
                await updater.cleanupBeforeUpdate();
                await updater.executeInstaller(path);
                exit(0);
              }
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Onboarding Update Check Error: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _licenseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final credentials = await googleSignIn.signIn();
      if (credentials != null && credentials.accessToken != null) {
        // Fetch user info from Google API
        final response = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final name = data['name'] ?? '';
          final email = data['email'] ?? '';
          final photoUrl = data['picture'];

          ref.read(onboardingProvider.notifier).updateGoogleProfile(
            name: name,
            email: email,
            photoUrl: photoUrl,
          );
          _nameController.text = name;
        }

        // LANGSUNG PINDAH HALAMAN (Jangan menunggu Drive)
        if (mounted) {
          _proceedToNextStep();
        }
        
        // Cek Drive di latar belakang (Background)
        _checkDriveForBackup();
        
      } else {
        debugPrint('Google Sign-In aborted');
      }
    } catch (error) {
      debugPrint('Google Sign-In Global Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal login Google: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _checkDriveForBackup() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      
      final driveFiles = await ref.read(googleDriveServiceProvider).listAppDataFiles();
      if (mounted && driveFiles.any((f) => f.name == 'vector_store.db')) {
        _showRestoreDialog();
      }
    } catch (e) {
      debugPrint('Background Drive check failed: $e');
    }
  }

  void _proceedToNextStep() {
    ref.read(onboardingProvider.notifier).nextStep();
    _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  void _showRestoreDialog() {
    bool isRestoring = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Backup Ditemukan'),
            content: isRestoring 
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Mendownload data riset lama Anda, mohon tunggu...'),
                  ],
                )
              : const Text('Kami menemukan data riset lama Anda di Google Drive. Apakah Anda ingin mengembalikannya sekarang?'),
            actions: isRestoring ? [] : [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _proceedToNextStep();
                },
                child: const Text('Mulai Baru'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!mounted) return;
                  setState(() => isRestoring = true);
                  await ref.read(syncProvider.notifier).performRestore();
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                    _proceedToNextStep();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restore Data Saya'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final licenseState = ref.watch(licenseStateProvider);

    // Sinkronisasi posisi halaman jika memori provider (Hive) baru saja selesai dimuat
    if (!_isInitialSyncDone && onboardingState.currentStep > 0) {
      _isInitialSyncDone = true;
      if (onboardingState.googleName != null) {
        _nameController.text = onboardingState.googleName!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(onboardingState.currentStep);
        }
      });
    }

    if (onboardingState.isAuthenticating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
              const SizedBox(height: 24),
              Text(
                'Memulihkan sesi...',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: GlassmorphismTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu sebentar',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: GlassmorphismTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlassmorphismTheme.backgroundStart,
              GlassmorphismTheme.backgroundEnd,
              Color(0xFFE3F2FD), // Subtle blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorations
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GlassmorphismTheme.primaryRed.withOpacity(0.05),
                ),
              ),
            ),
            
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 480,
                    height: 560,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Progress bar
                        _buildProgressBar(onboardingState.currentStep),
                        
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep1Welcome(),
                              _buildStep2ProfileAndLicense(licenseState),
                              _buildStep3Survey(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Row(
        children: List.generate(3, (index) {
          bool isActive = index <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive ? GlassmorphismTheme.primaryRed : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1Welcome() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school_rounded, size: 64, color: GlassmorphismTheme.primaryRed),
          ),
          const SizedBox(height: 32),
          Text(
            'Selamat Datang!',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Langkah awal menuju skripsi yang lebih terstruktur dan cerdas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary),
          ),
          const SizedBox(height: 48),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isGoogleLoading ? null : _handleSignIn,
              icon: _isGoogleLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png', height: 24, width: 24, 
                errorBuilder: (_,__,___) => const Icon(Icons.login),
              ),
              label: Text(_isGoogleLoading ? 'Menyambungkan...' : 'Lanjutkan dengan Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                side: const BorderSide(color: Colors.black12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Data Anda akan tersinkronisasi otomatis ke Google Drive.',
            style: TextStyle(fontSize: 11, color: GlassmorphismTheme.textSecondary.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ProfileAndLicense(AsyncValue<dynamic> licenseState) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil & Lisensi',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Verifikasi akun untuk membuka akses penuh.',
            style: GoogleFonts.inter(fontSize: 13, color: GlassmorphismTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Lengkap',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: Colors.black.withOpacity(0.03),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _licenseController,
            decoration: InputDecoration(
              labelText: 'Kode Lisensi',
              prefixIcon: const Icon(Icons.key_rounded),
              filled: true,
              fillColor: Colors.black.withOpacity(0.03),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ID PERANGKAT: $_deviceId',
              style: GoogleFonts.inter(
                fontSize: 10, 
                color: GlassmorphismTheme.textSecondary.withOpacity(0.5),
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Spacer(),
          
          licenseState.when(
            data: (license) {
              // Hanya tampilkan centang hijau jika user baru saja memvalidasi ATAU 
              // isi text field cocok dengan lisensi di memori. 
              // Jika text field kosong (misal karena reset), paksa mereka input ulang.
              if (license != null && license.isActive && _licenseController.text.trim() == license.key) {
                // Navigasi paksa tanpa syarat step untuk menghindari bug nyangkut di icon hijau
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients) {
                    ref.read(onboardingProvider.notifier).nextStep(); // Pastikan step naik
                    _pageController.animateToPage(
                      2, // Langsung paksa ke halaman Survey (index 2)
                      duration: const Duration(milliseconds: 400), 
                      curve: Curves.easeOutCubic
                    );
                  }
                });
                return const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 40));
              }
              return _buildValidateButton(false);
            },
            loading: () => _buildValidateButton(true),
            error: (e, _) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''), 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 16),
                _buildValidateButton(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidateButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          if (_nameController.text.trim().isEmpty || _licenseController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nama Lengkap dan Kode Lisensi wajib diisi')),
            );
            return;
          }
          ref.read(licenseStateProvider.notifier).validate(
            name: _nameController.text.trim(),
            key: _licenseController.text.trim(),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassmorphismTheme.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Verifikasi Lisensi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStep3Survey() {
    final options = ['Instagram', 'TikTok', 'YouTube', 'Teman / Rekomendasi', 'Iklan', 'Lainnya'];
    
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Satu hal lagi...',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Dari mana Anda mengetahui aplikasi ini?',
            style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                bool isSelected = ref.watch(onboardingProvider).surveySource == option;
                
                return GestureDetector(
                  onTap: () => ref.read(onboardingProvider.notifier).setSurveySource(option),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? GlassmorphismTheme.primaryRed : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(option, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black87,
                        )),
                        const Spacer(),
                        if (isSelected) const Icon(Icons.check_circle_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (ref.watch(onboardingProvider).surveySource == null || _isCompleting) 
                ? null 
                : () async {
                setState(() => _isCompleting = true);
                try {
                  final onboarding = ref.read(onboardingProvider);
                  // Kirim data dan tunggu sebentar
                  await ref.read(onboardingProvider.notifier).completeOnboarding(
                    name: _nameController.text.trim(),
                    email: onboarding.googleEmail,
                  );
                  
                  if (mounted) {
                    widget.onCompleted();
                  }
                } catch (e) {
                  debugPrint('Error completing onboarding: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengirim survey: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isCompleting = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: GlassmorphismTheme.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isCompleting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Mulai Gunakan Aplikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
