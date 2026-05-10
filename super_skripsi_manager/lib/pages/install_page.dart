import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/extension_installer_terminal.dart';

class InstallPage extends StatelessWidget {
  const InstallPage({super.key});

  Future<String?> _findScript(String subDir, String fileName) async {
    final exePath = Platform.resolvedExecutable;
    final appDir = p.dirname(exePath);

    // 1. Cek di folder exe (Production/Bundle)
    final prodPath = p.join(appDir, subDir, fileName);
    if (await File(prodPath).exists()) return prodPath;

    // 2. Jika tidak ada, coba cari di folder source (Development/Debug)
    // Asumsi struktur: root/super_skripsi_manager/build/windows/x64/runner/Debug/exe
    // Maka 5 level ke atas adalah super_skripsi_manager
    final projectRoot = p.join(appDir, '..', '..', '..', '..', '..');
    final workspaceRoot = p.join(projectRoot, '..');

    if (subDir == 'addin') {
      final devPath = p.join(projectRoot, 'assets', 'scripts', fileName);
      if (await File(devPath).exists()) return devPath;
    } else if (subDir == 'extension') {
      final devPath = p.join(workspaceRoot, 'super_skripsi_extension', fileName);
      if (await File(devPath).exists()) return devPath;
    }

    return null;
  }

  Future<void> _runInstaller(BuildContext context) async {
    try {
      final scriptPath = await _findScript('addin', 'install_addin.bat');

      if (scriptPath == null) {
        throw Exception('Installer script not found. Pastikan folder "addin" ada di samping file .exe atau Anda menjalankan dari source dengan struktur folder yang benar.');
      }

      // On Windows, use 'cmd /c start' to open in a new visible window
      await Process.run('cmd', ['/c', 'start', '', scriptPath]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installer launched in CMD window.'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching installer: $e'),
          backgroundColor: GlassmorphismTheme.error,
        ),
      );
    }
  }

  Future<void> _runExtensionInstaller(BuildContext context) async {
    try {
      final scriptPath = await _findScript('extension', 'One-Click-Install.bat');

      if (scriptPath == null) {
        throw Exception('Extension installer script not found.');
      }

      await Process.run('cmd', ['/c', 'start', '', scriptPath]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extension Installer launched.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: GlassmorphismTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Word Integration',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hubungkan Super Skripsi Gandi dengan Microsoft Word Anda.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: GlassmorphismTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          GlassCard(
            child: Column(
              children: [
                const Icon(
                  Icons.description_rounded,
                  size: 64,
                  color: GlassmorphismTheme.primaryRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Instalasi Add-in Otomatis',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: GlassmorphismTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Klik tombol di bawah untuk mendaftarkan folder proyek sebagai "Trusted Catalog" di Microsoft Word. Jendela CMD akan terbuka untuk memproses pendaftaran.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: GlassmorphismTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 240,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _runInstaller(context),
                    icon: const Icon(Icons.install_desktop_rounded),
                    label: const Text('Install ke Word'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassmorphismTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Langkah Manual Setelah Instalasi:',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            '1',
            'Buka Microsoft Word (atau restart jika sudah terbuka).',
          ),
          _buildStep(
            '2',
            'Pindah ke Tab "Insert" (Sisipkan).',
          ),
          _buildStep(
            '3',
            'Klik "My Add-ins" (Add-in Saya).',
          ),
          _buildStep(
            '4',
            'Klik tab "Shared Folder" (Folder Bersama) atau "Developer".',
          ),
          _buildStep(
            '5',
            'Pilih "Super Skripsi Gandi" dan klik Add.',
          ),

          const SizedBox(height: 48),

          // Browser Extension Section
          Text(
            'Browser Extension Integration',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: GlassmorphismTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Instal ekstensi untuk otomatisasi di Gemini, ChatGPT, Claude, dan DeepSeek.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: GlassmorphismTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _BrowserExtensionInstaller(),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: GlassmorphismTheme.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: GlassmorphismTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserExtensionInstaller extends StatefulWidget {
  const _BrowserExtensionInstaller();

  @override
  State<_BrowserExtensionInstaller> createState() => _BrowserExtensionInstallerState();
}

class _BrowserExtensionInstallerState extends State<_BrowserExtensionInstaller> {
  String _selectedBrowser = 'Chrome';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBrowserBtn('Chrome', Icons.chrome_reader_mode_rounded),
            const SizedBox(width: 12),
            _buildBrowserBtn('Edge', Icons.window_rounded),
            const SizedBox(width: 12),
            _buildBrowserBtn('Firefox', Icons.browser_updated_rounded),
          ],
        ),
        const SizedBox(height: 24),
        ExtensionInstallerTerminal(browser: _selectedBrowser),
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: () => const InstallPage()._runExtensionInstaller(context),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Auto-Install (Beta)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80).withOpacity(0.8),
              foregroundColor: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Note: Ekstensi harus di-load secara manual sebagai "Unpacked Extension" karena masih dalam mode pengembangan.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: GlassmorphismTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBrowserBtn(String name, IconData icon) {
    final isSelected = _selectedBrowser == name;
    return InkWell(
      onTap: () => setState(() => _selectedBrowser = name),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? GlassmorphismTheme.primaryRed 
              : GlassmorphismTheme.primaryRed.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : GlassmorphismTheme.primaryRed.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : GlassmorphismTheme.primaryRed),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
