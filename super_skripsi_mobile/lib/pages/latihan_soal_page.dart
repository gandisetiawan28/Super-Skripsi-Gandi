import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/latihan_provider.dart';
import '../models/latihan_model.dart';

class LatihanSoalPage extends ConsumerStatefulWidget {
  const LatihanSoalPage({super.key});

  @override
  ConsumerState<LatihanSoalPage> createState() => _LatihanSoalPageState();
}

class _LatihanSoalPageState extends ConsumerState<LatihanSoalPage> {
  int _timerSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(latihanSessionProvider.notifier).onTimerTick = (seconds) {
        if (mounted) setState(() => _timerSeconds = seconds);
      };
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(latihanSessionProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GlassmorphismTheme.backgroundStart,
              GlassmorphismTheme.backgroundEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildContent(session),
        ),
      ),
    );
  }

  Widget _buildContent(LatihanSession session) {
    switch (session.status) {
      case LatihanStatus.generating:
        return _buildGeneratingState(session);
      case LatihanStatus.error:
        return _buildErrorState(session);
      case LatihanStatus.active:
        return _buildActiveState(session);
      case LatihanStatus.selesai:
        return _buildResultState(session);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneratingState(LatihanSession session) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
            const SizedBox(height: 32),
            Text(
              'Menyiapkan Soal Ujian...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              session.generateLogs.isNotEmpty ? session.generateLogs.last : 'Mohon tunggu sebentar...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: GlassmorphismTheme.textSecondary),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () {
                ref.read(latihanSessionProvider.notifier).reset();
                Navigator.pop(context);
              },
              child: const Text('Batalkan', style: TextStyle(color: GlassmorphismTheme.primaryRed)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(LatihanSession session) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: GlassmorphismTheme.primaryRed),
              const SizedBox(height: 16),
              const Text('Gagal Membuat Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Text(
                session.errorMessage ?? 'Terjadi kesalahan tidak dikenal.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: GlassmorphismTheme.primaryRed),
                  child: const Text('Kembali', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveState(LatihanSession session) {
    if (session.soalList.isEmpty) return const SizedBox.shrink();
    final currentSoal = session.soalAktif!;
    final isLast = session.soalAktifIndex == session.soalList.length - 1;

    return Column(
      children: [
        _buildActiveHeader(session),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSoalCard(currentSoal, session),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _buildMobileNavigation(session, isLast),
      ],
    );
  }

  Widget _buildActiveHeader(LatihanSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _confirmExit(),
            icon: const Icon(Icons.close_rounded, color: GlassmorphismTheme.textPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soal ${session.soalAktifIndex + 1} / ${session.soalList.length}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                LinearProgressIndicator(
                  value: (session.soalAktifIndex + 1) / session.soalList.length,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: GlassmorphismTheme.primaryRed,
                  minHeight: 4,
                ),
              ],
            ),
          ),
          if (session.settings.timerAktif)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _timerSeconds < 60 ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatTime(_timerSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _timerSeconds < 60 ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berhenti Latihan?'),
        content: const Text('Progres pengerjaan saat ini tidak akan disimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Lanjut')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Ya, Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSoalCard(SoalLatihan soal, LatihanSession session) {
    final userJawaban = session.jawabanUser[soal.nomorSoal];

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            soal.pertanyaan,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 24),
          ...['A', 'B', 'C', 'D'].map((key) => _buildOption(key, soal.getPilihan(key), userJawaban == key, (v) {
                ref.read(latihanSessionProvider.notifier).jawabSoal(soal.nomorSoal, v);
              })),
        ],
      ),
    );
  }

  Widget _buildOption(String key, String text, bool isSelected, Function(String) onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onTap(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? GlassmorphismTheme.primaryRed : Colors.white.withOpacity(0.1),
                ),
                child: Center(
                  child: Text(key, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : GlassmorphismTheme.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavigation(LatihanSession session, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GlassmorphismTheme.backgroundStart.withOpacity(0.8),
        border: const Border(top: BorderSide(color: GlassmorphismTheme.borderGlass)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (session.soalAktifIndex > 0)
            IconButton(
              onPressed: () => ref.read(latihanSessionProvider.notifier).goToSoal(session.soalAktifIndex - 1),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            )
          else
            const SizedBox(width: 48),
          
          ElevatedButton(
            onPressed: () {
              if (isLast) {
                ref.read(latihanSessionProvider.notifier).selesaikanLatihan();
              } else {
                ref.read(latihanSessionProvider.notifier).goToSoal(session.soalAktifIndex + 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? Colors.green : GlassmorphismTheme.primaryRed,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isLast ? 'SELESAI' : 'LANJUT', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),

          if (!isLast)
            IconButton(
              onPressed: () => ref.read(latihanSessionProvider.notifier).goToSoal(session.soalAktifIndex + 1),
              icon: const Icon(Icons.arrow_forward_ios_rounded),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildResultState(LatihanSession session) {
    final score = session.skor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('Hasil Ujian', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(latihanSessionProvider.notifier).reset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('Skor Akhir', style: GoogleFonts.inter(fontSize: 16, color: GlassmorphismTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        '$score',
                        style: GoogleFonts.inter(fontSize: 64, fontWeight: FontWeight.bold, color: score >= 70 ? Colors.green : GlassmorphismTheme.primaryRed),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _resultStat('Benar', '${session.jumlahBenar}', Colors.green),
                          _resultStat('Salah', '${session.soalList.length - session.jumlahBenar}', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Review Jawaban'),
                ...session.soalList.map((soal) => _buildReviewCard(soal, session)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildReviewCard(SoalLatihan soal, LatihanSession session) {
    final userJawaban = session.jawabanUser[soal.nomorSoal];
    final isCorrect = userJawaban == soal.jawabanBenar;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? Colors.green : Colors.red, size: 16),
              const SizedBox(width: 8),
              Text('Soal ${soal.nomorSoal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(soal.pertanyaan, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Jawaban Benar: ${soal.jawabanBenar}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
          if (!isCorrect)
            Text('Jawaban Anda: ${userJawaban ?? "-"}', style: const TextStyle(fontSize: 12, color: Colors.red)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Text(
              soal.penjelasanBenar,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: GlassmorphismTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
