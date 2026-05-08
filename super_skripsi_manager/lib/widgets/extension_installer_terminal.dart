import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExtensionInstallerTerminal extends StatefulWidget {
  final String browser;
  const ExtensionInstallerTerminal({super.key, required this.browser});

  @override
  State<ExtensionInstallerTerminal> createState() => _ExtensionInstallerTerminalState();
}

class _ExtensionInstallerTerminalState extends State<ExtensionInstallerTerminal> {
  final String _extensionPath = 'D:\\SUPER SKRIPSI GANDI\\super_skripsi_extension';

  List<String> get _getCommands {
    switch (widget.browser.toLowerCase()) {
      case 'chrome':
        return [
          '# Membuka Chrome Extension Manager...',
          '> Buka chrome://extensions di browser Anda',
          '> Aktifkan "Developer Mode" di pojok kanan atas',
          '> Klik "Load unpacked"',
          '> Pilih folder: $_extensionPath',
          '# STATUS: Siap untuk instalasi'
        ];
      case 'edge':
        return [
          '# Membuka Edge Extension Manager...',
          '> Buka edge://extensions di browser Anda',
          '> Aktifkan "Developer Mode" di sidebar kiri',
          '> Klik "Load unpacked"',
          '> Pilih folder: $_extensionPath',
          '# STATUS: Siap untuk instalasi'
        ];
      case 'firefox':
        return [
          '# Membuka Firefox Debugging...',
          '> Buka about:debugging#/runtime/this-firefox',
          '> Klik "Load Temporary Add-on..."',
          '> Pilih file manifest.json di: $_extensionPath',
          '# STATUS: Siap untuk instalasi (Temporary)'
        ];
      default:
        return ['# Browser tidak dikenal'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final commands = _getCommands;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Terminal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF323233),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _buildDot(const Color(0xFFFF5F56)),
                const SizedBox(width: 8),
                _buildDot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 8),
                _buildDot(const Color(0xFF27C93F)),
                const SizedBox(width: 16),
                Text(
                  'Terminal - Install Extension (${widget.browser})',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Terminal Content
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: commands.map((cmd) {
                final isHeader = cmd.startsWith('#');
                final isAction = cmd.startsWith('>');
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    cmd,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      color: isHeader 
                          ? const Color(0xFF4ADE80) 
                          : isAction 
                              ? Colors.white 
                              : Colors.white70,
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
