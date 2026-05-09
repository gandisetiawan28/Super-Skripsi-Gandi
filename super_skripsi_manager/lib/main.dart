import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/glassmorphism_theme.dart';
import 'widgets/glass_nav_dock.dart';
import 'pages/onboarding_page.dart';
import 'pages/dashboard_page.dart';

import 'pages/blueprint_page.dart';
import 'pages/api_keys_page.dart';
import 'pages/api_usage_page.dart';
import 'pages/research_page.dart';
import 'pages/rag_explorer_page.dart';
import 'pages/logs_page.dart';
import 'pages/settings_page.dart';
import 'pages/install_page.dart';
import 'pages/extension_page.dart';
import 'pages/latihan_setup_page.dart';
import 'providers/license_provider.dart';
import 'providers/server_provider.dart';
import 'providers/addin_launcher_provider.dart';
import 'providers/rag_service_provider.dart';
import 'package:provider/provider.dart' as pk_provider;
import 'services/api_bridge_service.dart';
import 'providers/stats_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/sync_service.dart';
import 'services/updater_service.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Configure window
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Super Skripsi Gandi Manager',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      child: pk_provider.MultiProvider(
        providers: [
          pk_provider.ChangeNotifierProvider<ApiBridgeService>(
            create: (_) => ApiBridgeService(),
          ),
          pk_provider.ChangeNotifierProvider<StatsProvider>(
            create: (context) => StatsProvider(),
          ),
        ],
        child: const SuperSkripsiApp(),
      ),
    ),
  );
}

class SuperSkripsiApp extends StatelessWidget {
  const SuperSkripsiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Skripsi Gandi Manager',
      theme: GlassmorphismTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AppGate(),
    );
  }
}

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseStateProvider);
    final onboarding = ref.watch(onboardingProvider);

    if (onboarding.isCompleted) {
      return license.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, __) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Gagal memuat lisensi: $e', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(licenseStateProvider),
                  child: const Text('Coba Lagi'),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(licenseStateProvider.notifier).logout();
                    ref.read(onboardingProvider.notifier).resetOnboarding();
                  },
                  child: const Text('Reset Sesi'),
                )
              ],
            ),
          ),
        ),
        data: (licenseData) {
          if (licenseData != null && licenseData.isActive) {
            return const MainShell();
          }
          // Jika lisensi benar-benar hilang/mati, paksa kembali ke Onboarding Step 1
          WidgetsBinding.instance.addPostFrameCallback((_) {
             ref.read(licenseStateProvider.notifier).logout();
             ref.read(onboardingProvider.notifier).resetOnboarding();
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    } else {
      return OnboardingPage(
        onCompleted: () => ref.refresh(licenseStateProvider),
      );
    }
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {

  final _pages = const [
    DashboardPage(),      // 0
    BlueprintPage(),      // 1
    ResearchPage(),       // 2
    RagExplorerPage(),    // 3
    LatihanSetupPage(),   // 4
    ExtensionPage(),      // 5
    SettingsPage(),       // 6
    ApiKeysPage(),        // 7
    ApiUsagePage(),       // 8
    InstallPage(),        // 9
    LogsPage(),           // 10
  ];

  bool _isUpdateDialogOpen = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Auto-start services on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(serverProvider.notifier).startServer();
      ref.read(addinLauncherProvider.notifier).start();
      // Auto-start Python RAG service (fire-and-forget, tidak block startup)
      ref.read(ragStateProvider.notifier).initialize();

      // Auto-start API Bridge (Node.js)
      final apiService = pk_provider.Provider.of<ApiBridgeService>(context, listen: false);
      await apiService.startServer();

      // Check for updates
      _checkUpdates();
      
      // Start periodic check every 1 hour
      _updateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
        _checkUpdates();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jika aplikasi kembali aktif dari background/minimized
    if (state == AppLifecycleState.resumed) {
      _checkUpdates();
    }
  }

  void _checkUpdates() async {
    if (_isUpdateDialogOpen) return; // Jangan cek jika dialog sudah terbuka

    final updater = UpdaterService();
    try {
      final info = await updater.checkForUpdate();
      if (info != null && info.hasInstaller && mounted) {
        setState(() => _isUpdateDialogOpen = true);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            updateInfo: info,
            onDownload: (url, name, progress) async {
              final path = await updater.downloadUpdate(url, name, onProgress: progress);
              if (path != null) {
                await updater.executeInstaller(path);
                // Matikan aplikasi agar installer bisa menimpa file lama
                exit(0);
              }
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isUpdateDialogOpen = false);
        });
      }
    } catch (e) {
      debugPrint('Auto-Update Check Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlassmorphismTheme.backgroundStart,
              GlassmorphismTheme.backgroundEnd,
              Color(0xFFFCE4EC),
            ],
          ),
        ),
        child: Column(
          children: [
            // Custom title bar
            GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // macOS-style traffic lights
                    _TrafficLight(
                      color: const Color(0xFFFF5F57),
                      onTap: () => windowManager.close(),
                    ),
                    const SizedBox(width: 6),
                    _TrafficLight(
                      color: const Color(0xFFFFBD2E),
                      onTap: () => windowManager.minimize(),
                    ),
                    const SizedBox(width: 6),
                    _TrafficLight(
                      color: const Color(0xFF28C940),
                      onTap: () async {
                        final isMax = await windowManager.isMaximized();
                        if (isMax) {
                          windowManager.unmaximize();
                        } else {
                          windowManager.maximize();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Super Skripsi Gandi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: GlassmorphismTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // RAG Service Status Badge
                    const _RagStatusBadge(),
                    const SizedBox(width: 8),
                    const _WordStatusBadge(),
                    const SizedBox(width: 8),
                    const _ExtensionStatusBadge(),
                    const SizedBox(width: 8),
                    const _SyncStatusBadge(),
                  ],
                ),
              ),
            ),

            // Page content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(ref.watch(navigationProvider)),
                  child: _pages[ref.watch(navigationProvider)],
                ),
              ),
            ),
          ],
        ),
      ),

      // Floating glass navigation dock
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassNavDock(
          selectedIndex: ref.watch(navigationProvider),
          onItemTapped: (index) {
            ref.read(navigationProvider.notifier).state = index;
          },
        ),
      ),
    );
  }
}

class _TrafficLight extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _TrafficLight({required this.color, required this.onTap});

  @override
  State<_TrafficLight> createState() => _TrafficLightState();
}

class _TrafficLightState extends State<_TrafficLight> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 6)]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Badge yang menampilkan status Python RAG service di title bar
class _RagStatusBadge extends ConsumerStatefulWidget {
  const _RagStatusBadge();

  @override
  ConsumerState<_RagStatusBadge> createState() => _RagStatusBadgeState();
}

class _RagStatusBadgeState extends ConsumerState<_RagStatusBadge> {
  @override
  void initState() {
    super.initState();
    // Refresh RAG status setiap 15 detik
    Future.delayed(const Duration(seconds: 5), _periodicRefresh);
  }

  void _periodicRefresh() {
    if (!mounted) return;
    ref.read(ragStateProvider.notifier).refresh();
    Future.delayed(const Duration(seconds: 15), _periodicRefresh);
  }

  @override
  Widget build(BuildContext context) {
    final ragState = ref.watch(ragStateProvider);

    Color dotColor;
    Color bgColor;
    switch (ragState.status) {
      case RagStatus.ready:
        dotColor = const Color(0xFF4ADE80);  // Hijau
        bgColor = const Color(0xFF166534).withOpacity(0.6);
        break;
      case RagStatus.loading:
      case RagStatus.starting:
        dotColor = const Color(0xFFFBBF24);  // Kuning
        bgColor = const Color(0xFF78350F).withOpacity(0.6);
        break;
      default:
        dotColor = const Color(0xFFEF4444);  // Merah untuk offline
        bgColor = dotColor.withOpacity(0.1);
    }

    return Tooltip(
      message: ragState.tooltipLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dotColor.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: ragState.isActive
                    ? [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              ragState.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dotColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge yang menampilkan status MS Word Bridge (Dart Server)
class _WordStatusBadge extends ConsumerWidget {
  const _WordStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverProvider);
    
    final bool isOnline = serverState.isRunning;
    final Color dotColor = isOnline ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
    final Color bgColor = isOnline 
        ? const Color(0xFF166534).withOpacity(0.6) 
        : dotColor.withOpacity(0.1);

    return Tooltip(
      message: isOnline 
          ? 'Word Bridge aktif di port ${serverState.port} — Menghubungkan Manager dengan MS Word' 
          : 'Word Bridge mati — MS Word tidak dapat mengakses data',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dotColor.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: isOnline
                    ? [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnline ? '📝 Word' : '📝 Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dotColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge yang menampilkan status Browser Extension Bridge (Node.js Server)
class _ExtensionStatusBadge extends StatelessWidget {
  const _ExtensionStatusBadge();

  @override
  Widget build(BuildContext context) {
    return pk_provider.Consumer2<ApiBridgeService, StatsProvider>(
      builder: (context, apiService, stats, child) {
        // Status online jika bridge aktif DAN minimal ada 1 provider yang online
        final bool isServerRunning = apiService.isRunning;
        final bool hasProviders = stats.isOnline && stats.activeProviders > 0;
        final bool isFullyOnline = isServerRunning && hasProviders;
        
        final Color dotColor = isFullyOnline ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);
        final Color bgColor = isFullyOnline 
            ? const Color(0xFF166534).withOpacity(0.6) 
            : dotColor.withOpacity(0.1);

        String label = '🧩 Offline';
        String tooltip = 'Extension Bridge mati — Browser Extension tidak dapat mengakses data';
        
        if (isServerRunning) {
          if (hasProviders) {
            label = '🧩 Extension';
            tooltip = 'Extension Bridge aktif — ${stats.activeProviders} AI Provider terhubung';
          } else {
            label = '🧩 Standby';
            tooltip = 'Extension Bridge aktif, tapi belum ada AI Provider yang online di Browser';
          }
        }

        return Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dotColor.withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: isFullyOnline
                        ? [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SyncStatusBadge extends ConsumerWidget {
  const _SyncStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    
    Color dotColor;
    String label;
    IconData icon;

    switch (syncState.status) {
      case SyncStatus.syncing:
        dotColor = Colors.orange;
        label = syncState.message ?? 'Syncing...';
        icon = Icons.sync_rounded;
        break;
      case SyncStatus.error:
        dotColor = Colors.red;
        label = syncState.message ?? 'Sync Error';
        icon = Icons.cloud_off_rounded;
        break;
      case SyncStatus.success:
      default:
        dotColor = Colors.green;
        label = syncState.message ?? 'Synced';
        icon = Icons.cloud_done_rounded;
        break;
    }

    return Tooltip(
      message: syncState.lastSync != null 
          ? 'Last synced: ${syncState.lastSync!.toString().split('.')[0]}'
          : 'Data belum disinkronkan',
      child: GestureDetector(
        onTap: () => ref.read(syncProvider.notifier).performSync(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dotColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dotColor.withOpacity(0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: dotColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
