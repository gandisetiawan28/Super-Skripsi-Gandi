import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/glassmorphism_theme.dart';
import '../widgets/glass_card.dart';
import '../providers/latihan_provider.dart';
import '../models/latihan_model.dart';
import '../providers/rag_service_provider.dart';

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

  String _formatFriendlyError(String rawError) {
    if (rawError.contains('429')) {
      return '[Error 429]: Kuota AI Anda habis atau terlalu sering mengirim permintaan. Silakan tunggu beberapa menit atau gunakan API Key yang berbeda.';
    } else if (rawError.contains('401')) {
      return '[Error 401]: API Key tidak valid. Silakan periksa kembali konfigurasi API Key Anda di menu pengaturan.';
    } else if (rawError.contains('404')) {
      return '[Error 404]: Model AI tidak ditemukan. Coba ganti ke model lain atau periksa provider Anda.';
    } else if (rawError.contains('SocketException') || rawError.contains('Timeout')) {
      return '[Error Network]: Koneksi internet bermasalah atau server tidak merespons. Pastikan internet Anda stabil.';
    } else if (rawError.contains('413')) {
      return '[Error 413]: Dokumen terlalu besar untuk diproses oleh model ini. Coba gunakan model dengan context window lebih besar.';
    }
    return rawError;
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
        child: _buildContent(session),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: GlassmorphismTheme.primaryRed),
          const SizedBox(height: 24),
          Text('Sedang Menyiapkan Soal...', 
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: GlassmorphismTheme.textPrimary)),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: session.generateLogs.reversed.take(3).map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(log, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary)),
              )).toList(),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // Hentikan AI di browser/bridge jika sedang jalan
              ref.read(ragStateProvider.notifier).abortIndexing();
              ref.read(latihanSessionProvider.notifier).reset();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Batalkan dan Kembali'),
            style: OutlinedButton.styleFrom(
              foregroundColor: GlassmorphismTheme.primaryRed,
              side: BorderSide(color: GlassmorphismTheme.primaryRed.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(LatihanSession session) {
    final friendlyMsg = _formatFriendlyError(session.errorMessage ?? 'Terjadi kesalahan tidak dikenal.');
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: GlassmorphismTheme.primaryRed),
              const SizedBox(height: 16),
              const Text('Waduh, Gagal Generate Soal', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(friendlyMsg, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontSize: 14, color: GlassmorphismTheme.textSecondary, height: 1.5)),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlassmorphismTheme.textPrimary,
                      side: const BorderSide(color: GlassmorphismTheme.borderGlass),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(latihanSessionProvider.notifier).reset();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlassmorphismTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Keluar'),
                  ),
                ],
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

    return Column(
      children: [
        _buildActiveHeader(session),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    _buildSoalCard(currentSoal, session),
                    const SizedBox(height: 24),
                    _buildNavigationFooter(session),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveHeader(LatihanSession session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: GlassmorphismTheme.borderGlass)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: GlassmorphismTheme.textPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latihan Skripsi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(session.settings.namaFile ?? 'Untitled', style: const TextStyle(fontSize: 12, color: GlassmorphismTheme.textSecondary)),
            ],
          ),
          const Spacer(),
          if (session.settings.timerAktif)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _timerSeconds < 60 ? GlassmorphismTheme.primaryRed.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: _timerSeconds < 60 ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary),
                  const SizedBox(width: 8),
                  Text(_formatTime(_timerSeconds), 
                    style: TextStyle(fontWeight: FontWeight.bold, color: _timerSeconds < 60 ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSoalCard(SoalLatihan soal, LatihanSession session) {
    final userJawaban = session.jawabanUser[soal.nomorSoal];

    return GlassCard(
      hoverEffect: false,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: GlassmorphismTheme.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Soal ${session.soalAktifIndex + 1}', 
                  style: const TextStyle(color: GlassmorphismTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Text(soal.bab, style: const TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Text(soal.pertanyaan, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 32),
          ...['A', 'B', 'C', 'D'].map((key) => _buildOptionItem(key, soal.getPilihan(key), userJawaban == key, (v) {
            ref.read(latihanSessionProvider.notifier).jawabSoal(soal.nomorSoal, v);
          })),
        ],
      ),
    );
  }

  Widget _buildOptionItem(String key, String text, bool isSelected, Function(String) onTap) {
    return _OptionItem(
      keyChar: key,
      text: text,
      isSelected: isSelected,
      onTap: () => onTap(key),
    );
  }

  Widget _buildNavigationFooter(LatihanSession session) {
    final isLast = session.soalAktifIndex == session.soalList.length - 1;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (session.soalAktifIndex > 0)
          _navBtn('Sebelumnya', Icons.arrow_back_rounded, () {
            ref.read(latihanSessionProvider.notifier).goToSoal(session.soalAktifIndex - 1);
          })
        else
          const SizedBox(width: 100),
          
        Text('${session.soalAktifIndex + 1} / ${session.soalList.length}', 
          style: const TextStyle(fontWeight: FontWeight.bold, color: GlassmorphismTheme.textSecondary)),

        if (!isLast)
          _navBtn('Selanjutnya', Icons.arrow_forward_rounded, () {
            ref.read(latihanSessionProvider.notifier).goToSoal(session.soalAktifIndex + 1);
          }, isPrimary: true)
        else
          ElevatedButton(
            onPressed: () {
              ref.read(latihanSessionProvider.notifier).selesaikanLatihan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassmorphismTheme.primaryRed,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _navBtn(String label, IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? GlassmorphismTheme.primaryRed : Colors.black.withOpacity(0.05),
        foregroundColor: isPrimary ? Colors.white : GlassmorphismTheme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildResultState(LatihanSession session) {
    final correct = session.jumlahBenar;
    final total = session.soalList.length;
    final score = session.skor;

    return Column(
      children: [
        // FIXED HEADER FOR RESULT
        Container(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: const Border(bottom: BorderSide(color: GlassmorphismTheme.borderGlass)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  ref.read(latihanSessionProvider.notifier).reset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded, color: GlassmorphismTheme.textPrimary),
              ),
              const SizedBox(width: 12),
              Text('Hasil Latihan', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  ref.read(latihanSessionProvider.notifier).reset();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassmorphismTheme.primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tutup Sesi'),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // SKOR CARD
                    GlassCard(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 120,
                            width: 120,
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: const Size(120, 120),
                                  painter: DonutChartPainter(
                                    percentage: score / 100,
                                    color: score >= 70 ? GlassmorphismTheme.success : (score >= 50 ? Colors.orange : GlassmorphismTheme.primaryRed),
                                  ),
                                ),
                                Center(
                                  child: Text('$score', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Skor Akhir Anda', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(score >= 70 ? 'Luar biasa! Pemahamanmu sangat kuat.' : 'Terus berlatih untuk hasil maksimal.', 
                                  style: const TextStyle(color: GlassmorphismTheme.textSecondary, fontSize: 13)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _statChip('Benar', '$correct', GlassmorphismTheme.success),
                                    const SizedBox(width: 12),
                                    _statChip('Salah', '${total - correct}', GlassmorphismTheme.primaryRed),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // REVIEW SECTION HEADER
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.fact_check_rounded, color: GlassmorphismTheme.primaryRed, size: 20),
                          const SizedBox(width: 8),
                          Text('Review Jawaban & Penjelasan', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    
                    // DAFTAR REVIEW SOAL
                    ...session.soalList.map((soal) => _buildReviewSoalCard(soal, session)),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(val, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReviewSoalCard(SoalLatihan soal, LatihanSession session) {
    final userJawaban = session.jawabanUser[soal.nomorSoal];
    final isCorrect = userJawaban == soal.jawabanBenar;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCorrect ? GlassmorphismTheme.success.withOpacity(0.1) : GlassmorphismTheme.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Soal ${soal.nomorSoal}', style: TextStyle(
                  color: isCorrect ? GlassmorphismTheme.success : GlassmorphismTheme.primaryRed,
                  fontWeight: FontWeight.bold, fontSize: 11
                )),
              ),
              const SizedBox(width: 12),
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: isCorrect ? GlassmorphismTheme.success : GlassmorphismTheme.primaryRed,
              ),
              const SizedBox(width: 4),
              Text(isCorrect ? 'Benar' : 'Salah', style: TextStyle(
                color: isCorrect ? GlassmorphismTheme.success : GlassmorphismTheme.primaryRed,
                fontWeight: FontWeight.bold, fontSize: 11
              )),
            ],
          ),
          const SizedBox(height: 16),
          Text(soal.pertanyaan, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4)),
          const SizedBox(height: 20),
          
          // REVIEW PILIHAN JAWABAN
          ...['A', 'B', 'C', 'D'].map((key) {
            final isUserChoice = userJawaban == key;
            final isCorrectAnswer = soal.jawabanBenar == key;
            
            Color bgColor = Colors.transparent;
            Color borderColor = GlassmorphismTheme.borderGlass;
            
            if (isCorrectAnswer) {
              bgColor = GlassmorphismTheme.success.withOpacity(0.1);
              borderColor = GlassmorphismTheme.success;
            } else if (isUserChoice && !isCorrectAnswer) {
              bgColor = GlassmorphismTheme.primaryRed.withOpacity(0.1);
              borderColor = GlassmorphismTheme.primaryRed;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text('$key. ', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrectAnswer ? GlassmorphismTheme.success : (isUserChoice ? GlassmorphismTheme.primaryRed : GlassmorphismTheme.textPrimary))),
                  Expanded(child: Text(soal.getPilihan(key), style: const TextStyle(fontSize: 13))),
                  if (isCorrectAnswer) const Icon(Icons.check_circle_outline, size: 16, color: GlassmorphismTheme.success),
                  if (isUserChoice && !isCorrectAnswer) const Icon(Icons.highlight_off_rounded, size: 16, color: GlassmorphismTheme.primaryRed),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // KOTAK PENJELASAN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GlassmorphismTheme.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('Penjelasan:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    String explText = soal.penjelasanBenar;
                    if (!isCorrect && userJawaban != null) {
                      String wrongExpl = '';
                      switch (userJawaban) {
                        case 'A': wrongExpl = soal.penjelasanSalahA; break;
                        case 'B': wrongExpl = soal.penjelasanSalahB; break;
                        case 'C': wrongExpl = soal.penjelasanSalahC; break;
                        case 'D': wrongExpl = soal.penjelasanSalahD; break;
                      }
                      if (wrongExpl.isNotEmpty) {
                        explText = 'Mengapa pilihan Anda ($userJawaban) salah:\n$wrongExpl\n\nMengapa jawaban benar (${soal.jawabanBenar}):\n${soal.penjelasanBenar}';
                      }
                    }
                    return Text(explText, style: const TextStyle(fontSize: 13, height: 1.5, fontStyle: FontStyle.italic));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double percentage;
  final Color color;

  DonutChartPainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _OptionItem extends StatefulWidget {
  final String keyChar;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionItem({
    required this.keyChar,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_OptionItem> createState() => _OptionItemState();
}

class _OptionItemState extends State<_OptionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool highlight = widget.isSelected || _isHovered;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isSelected 
                    ? GlassmorphismTheme.primaryRed.withOpacity(0.1) 
                    : (_isHovered ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
                border: Border.all(
                  color: widget.isSelected 
                      ? GlassmorphismTheme.primaryRed 
                      : (_isHovered ? GlassmorphismTheme.primaryRed.withOpacity(0.3) : GlassmorphismTheme.borderGlass)
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: highlight 
                          ? GlassmorphismTheme.primaryRed 
                          : Colors.black.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Text(
                        widget.keyChar, 
                        style: TextStyle(
                          color: highlight ? Colors.white : GlassmorphismTheme.textPrimary, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(widget.text, style: TextStyle(fontSize: 14, color: GlassmorphismTheme.textPrimary))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
