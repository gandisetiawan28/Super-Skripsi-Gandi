import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/glassmorphism_theme.dart';
import '../providers/onboarding_provider.dart';
import '../providers/license_provider.dart';
import '../services/device_info_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with TickerProviderStateMixin {
  late final PageController _pageController;
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _deviceId = "Memuat ID...";
  bool _isLoading = false;
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadDeviceInfo();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _licenseController.dispose();
    _nameController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    final id = await DeviceInfoService().getUniqueId();
    if (mounted) {
      setState(() {
        _deviceId = id.substring(0, 8).toUpperCase();
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final credentials = await googleSignIn.signIn();
      
      if (credentials != null && credentials.accessToken != null) {
        final response = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final name = data['name'] ?? '';
          final email = data['email'] ?? '';
          
          await ref.read(onboardingProvider.notifier).updateGoogleProfile(
            name: name,
            email: email,
            photoUrl: data['picture'],
          );
          _nameController.text = name;
          _proceedToNextStep();
          
          // Cek backup di latar belakang setelah login
          _checkDriveForBackup();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal login Google: $e'), backgroundColor: GlassmorphismTheme.primaryRed),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkDriveForBackup() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      
      final driveFiles = await ref.read(googleDriveServiceProvider).listAppDataFiles();
      if (mounted && driveFiles.any((f) => f.name != null && f.name!.contains('vector_store'))) {
        _showRestoreDialog();
      }
    } catch (e) {
      debugPrint('Background Drive check failed: $e');
    }
  }

  void _showRestoreDialog() {
    bool isRestoring = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Backup Ditemukan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: isRestoring 
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blue),
                    const SizedBox(height: 16),
                    Text('Mendownload data riset lama Anda...', style: GoogleFonts.inter(fontSize: 14)),
                  ],
                )
              : Text('Kami menemukan data riset Anda di Google Drive. Ingin memulihkannya sekarang?', style: GoogleFonts.inter(fontSize: 14)),
            actions: isRestoring ? [] : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Nanti Saja', style: GoogleFonts.inter(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  setLocalState(() => isRestoring = true);
                  await ref.read(syncProvider.notifier).performRestore();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Restore Sekarang'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _proceedToNextStep() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final licenseState = ref.watch(licenseStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          // ── Background Blobs ──
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: (-100.0) + (40.0 * _blobController.value.toDouble()),
                    right: (-100.0) + (30.0 * _blobController.value.toDouble()),
                    child: _buildBlob(400.0, GlassmorphismTheme.primaryRed.withOpacity(0.1)),
                  ),
                  Positioned(
                    bottom: (-50.0) - (20.0 * _blobController.value.toDouble()),
                    left: (-50.0) - (30.0 * _blobController.value.toDouble()),
                    child: _buildBlob(450.0, Colors.blue.withOpacity(0.08)),
                  ),
                ],
              );
            },
          ),

          // ── Main Content ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildProgressBar(onboardingState.currentStep ?? 0),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1Welcome(),
                      _buildStep2License(licenseState),
                      _buildStep3Survey(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildProgressBar(int step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Row(
        children: List.generate(3, (index) {
          bool isActive = index <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 4.0,
              margin: EdgeInsets.only(right: index == 2 ? 0.0 : 8.0),
              decoration: BoxDecoration(
                color: isActive ? GlassmorphismTheme.primaryRed : Colors.black12,
                borderRadius: BorderRadius.circular(2.0),
                boxShadow: isActive ? [BoxShadow(color: GlassmorphismTheme.primaryRed.withOpacity(0.3), blurRadius: 4.0)] : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1Welcome() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: GlassmorphismTheme.softShadow,
            ),
            child: Image.asset('assets/images/logo_nobg.png', height: 100.0),
          ),
          const SizedBox(height: 40.0),
          Text(
            'Selamat Datang!',
            style: GoogleFonts.outfit(fontSize: 32.0, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
          ),
          const SizedBox(height: 12.0),
          Text(
            'Langkah awal menuju skripsi yang lebih terstruktur dan cerdas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16.0, color: GlassmorphismTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 60.0),
          _buildActionButton(
            onPressed: _handleGoogleSignIn,
            isLoading: _isLoading,
            text: 'Lanjutkan dengan Google',
            icon: Icons.login_rounded,
          ),
          const SizedBox(height: 20),
          Text(
            'Data Anda akan tersinkron otomatis ke Google Drive.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black26, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2License(AsyncValue<dynamic> licenseState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'Profil & Lisensi',
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Verifikasi akun untuk membuka akses penuh.',
            style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary),
          ),
          const SizedBox(height: 40),
          _buildTextField(controller: _nameController, label: 'Nama Lengkap', icon: Icons.person_outline_rounded),
          const SizedBox(height: 20),
          _buildTextField(controller: _licenseController, label: 'Kode Lisensi', icon: Icons.vpn_key_outlined),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'ID PERANGKAT: $_deviceId',
              style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 40),
          licenseState.when(
            data: (license) {
              if (license != null && license.isActive && _licenseController.text.trim() == license.key) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(onboardingProvider.notifier).nextStep();
                  _proceedToNextStep();
                });
                return const Center(child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 48));
              }
              return _buildActionButton(
                onPressed: _handleValidateLicense,
                isLoading: false,
                text: 'Verifikasi Lisensi',
              );
            },
            loading: () => _buildActionButton(onPressed: () {}, isLoading: true, text: ''),
            error: (e, _) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(16.0)),
                  child: Text(e.toString().replaceAll('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13.0, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                _buildActionButton(onPressed: _handleValidateLicense, isLoading: false, text: 'Coba Lagi'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Survey() {
    final options = ['Instagram', 'TikTok', 'YouTube', 'Teman / Rekomendasi', 'Iklan', 'Lainnya'];
    final selectedSource = ref.watch(onboardingProvider).surveySource;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text('Satu hal lagi...', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Dari mana Anda mengetahui aplikasi ini?', style: GoogleFonts.inter(fontSize: 14, color: GlassmorphismTheme.textSecondary)),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                bool isSelected = selectedSource == option;
                return GestureDetector(
                  onTap: () => ref.read(onboardingProvider.notifier).setSurveySource(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.08) : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.05), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Text(option, style: GoogleFonts.inter(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary)),
                        const Spacer(),
                        if (isSelected) const Icon(Icons.check_circle_rounded, color: GlassmorphismTheme.primaryRed, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            onPressed: selectedSource == null ? null : _handleCompleteOnboarding,
            isLoading: _isLoading,
            text: 'Mulai Gunakan Aplikasi',
          ),
        ],
      ),
    );
  }

  void _handleValidateLicense() {
    if (_nameController.text.trim().isEmpty || _licenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama dan Kode Lisensi wajib diisi')));
      return;
    }
    ref.read(licenseStateProvider.notifier).validate(
      name: _nameController.text.trim(),
      key: _licenseController.text.trim(),
    );
  }

  Future<void> _handleCompleteOnboarding() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(onboardingProvider.notifier).completeOnboarding(
        name: _nameController.text.trim(),
        email: ref.read(onboardingProvider).googleEmail,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengirim survey: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10.0, offset: const Offset(0.0, 4.0))],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: GlassmorphismTheme.textSecondary),
          prefixIcon: Icon(icon, color: GlassmorphismTheme.primaryRed.withOpacity(0.7)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback? onPressed, required bool isLoading, required String text, IconData? icon}) {
    return Container(
      width: double.infinity,
      height: 60.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: (onPressed == null || isLoading) ? [] : GlassmorphismTheme.redGlowShadow,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlassmorphismTheme.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          disabledBackgroundColor: Colors.black12,
        ),
        child: isLoading
            ? const SizedBox(width: 24.0, height: 24.0, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20.0), const SizedBox(width: 12.0)],
                  Text(text, style: GoogleFonts.outfit(fontSize: 16.0, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}
