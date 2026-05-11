import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/glassmorphism_theme.dart';
import 'pages/research_page.dart';
import 'pages/latihan_setup_page.dart';
import 'pages/blueprint_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'providers/onboarding_provider.dart';
import 'providers/license_provider.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  runApp(
    const ProviderScope(
      child: SuperSkripsiMobileApp(),
    ),
  );
}

class SuperSkripsiMobileApp extends ConsumerWidget {
  const SuperSkripsiMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    final license = ref.watch(licenseStateProvider);
    
    // Logic: 
    // 1. If still authenticating (loading Hive), show a splash.
    // 2. If onboarding not completed OR license not valid, show LoginPage (Onboarding Flow).
    // 3. Otherwise, show the main application.
    
    if (onboarding.isAuthenticating) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: GlassmorphismTheme.theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
          ),
        ),
      );
    }

    final bool isBoarded = onboarding.isCompleted;
    final bool hasValidLicense = license.maybeWhen(
      data: (l) => l != null && l.isActive,
      orElse: () => false,
    );

    return MaterialApp(
      title: 'Super Skripsi Gandi Mobile',
      theme: GlassmorphismTheme.theme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0.0, end: 450.0, name: MOBILE),
          const Breakpoint(start: 451.0, end: 800.0, name: TABLET),
          const Breakpoint(start: 801.0, end: 1920.0, name: DESKTOP),
        ],
      ),
      home: (isBoarded && hasValidLicense) ? const MobileMainShell() : const LoginPage(),
    );
  }
}

class MobileMainShell extends StatefulWidget {
  const MobileMainShell({super.key});

  @override
  State<MobileMainShell> createState() => _MobileMainShellState();
}

class _MobileMainShellState extends State<MobileMainShell> {
  int _selectedIndex = 0;

  final _pages = [
    const DashboardPage(),
    const ResearchPage(),
    const LatihanSetupPage(),
    const BlueprintPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildGlassNavigationBar(),
    );
  }

  Widget _buildGlassNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20.0,
            offset: const Offset(0.0, 10.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.library_books_rounded, 'Riset'),
                _buildNavItem(2, Icons.psychology_rounded, 'AI'),
                _buildNavItem(3, Icons.architecture_rounded, 'Plan'),
                _buildNavItem(4, Icons.settings_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textSecondary,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: GlassmorphismTheme.primaryRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
