import '../models/latihan_model.dart';

/// Prompt generator untuk fitur Latihan Skripsi
class LatihanPrompt {
  static String buildSystemPrompt(PersonaDosen persona) {
    String rules = "";
    switch (persona) {
      case PersonaDosen.ramah:
        rules = "Gunakan nada bicara yang hangat, memotivasi, dan bahasa yang sederhana. Saat mahasiswa benar, berikan pujian dan jelaskan alasannya dengan logis dari skripsi. Saat salah, jelaskan letak kesalahannya dengan lembut.";
        break;
      case PersonaDosen.sedang:
        rules = "Gunakan nada bicara profesional, objektif, dan akademis. Penjelasan jawaban harus murni berbasis data dan fakta dari skripsi secara logis.";
        break;
      case PersonaDosen.killer:
        rules = "Gunakan nada bicara yang sangat kritis, dingin, dan tajam. Jika mahasiswa salah, tunjukkan betapa fatal kesalahannya secara logis berdasarkan skripsi.";
        break;
    }

    return '''KAMU ADALAH DOSEN PENGUJI SKRIPSI PROFESIONAL.
Karakter Spesifik Anda: $rules

TUGAS ANDA:
1. Membuat soal ujian skripsi berkualitas tinggi yang menguji pemahaman mahasiswa secara mendalam.
2. Selalu memberikan respons HANYA dalam format JSON Array yang valid.
3. DILARANG memberikan teks penjelasan, salam, atau komentar apapun di luar struktur JSON.
4. Pastikan semua istilah teknis sesuai dengan standar akademik Indonesia.
5. Jika teks sumber tidak cukup untuk membuat soal yang diminta, buatlah soal berdasarkan konteks penelitian umum yang paling relevan dengan sisa teks.''';
  }

  static String buildUserPrompt({
    required String pdfText,
    required int jumlahSoal,
    required List<String> babDipilih,
    required PersonaDosen persona,
    required LatihanLevel level,
  }) {
    final babTarget = babDipilih.contains('Semua') || babDipilih.isEmpty
        ? 'seluruh konten skripsi'
        : 'khusus pada bagian ${babDipilih.join(", ")}';

    String levelInstruction = "";
    String difficultyLabel = "";

    switch (level) {
      case LatihanLevel.level1:
        difficultyLabel = "Dasar/Konseptual (LOTS)";
        levelInstruction = "Fokus pada apa yang tertulis secara eksplisit. Pertanyaan harus menguji ingatan dan pemahaman dasar tentang istilah, tujuan, atau teori yang disebutkan di teks.";
        break;
      case LatihanLevel.level2:
        difficultyLabel = "Analitis/Logika (MOTS)";
        levelInstruction = "Fokus pada keterkaitan antar bagian teks. Pertanyaan harus menguji alasan pemilihan suatu metode, logika di balik data yang disajikan, atau bagaimana satu bagian mempengaruhi bagian lain.";
        break;
      case LatihanLevel.level3:
        difficultyLabel = "Kritis/Evaluatif (HOTS)";
        levelInstruction = "Fokus pada evaluasi mendalam. Pertanyaan harus berupa kritik, pengujian validitas, atau skenario di mana mahasiswa harus mempertahankan argumennya. Buat pengecoh yang sangat mirip dengan jawaban benar.";
        break;
    }

    return '''PERINTAH KERJA (IKUTI SECARA KETAT):
Buat tepat $jumlahSoal soal pilihan ganda (4 pilihan: A, B, C, D) berdasarkan teks skripsi berikut ini.

TARGET MATERI: $babTarget.
TINGKAT KESULITAN: $difficultyLabel.
INSTRUKSI LEVEL: $levelInstruction

--- SUMBER DATA (TEKS SKRIPSI) ---
$pdfText
--- AKHIR SUMBER DATA ---

SYARAT KONTEN SOAL & PENJELASAN:
1. Pertanyaan harus spesifik merujuk pada teks skripsi di atas (bukan pengetahuan umum).
2. Pilihan pengecoh (distractors) harus masuk akal, sangat meyakinkan, dan menantang.
3. Jawaban benar harus mutlak dan didukung secara eksplisit oleh isi teks.
4. "penjelasanBenar": Berisi pujian (jika sesuai persona), penjelasan spesifik secara logika (bersumber dari skripsi) mengapa jawaban tersebut mutlak benar, dan dampak jika tidak memilih jawaban ini.
5. "penjelasanSalahA/B/C/D": Berisi teguran/koreksi sesuai persona, lalu penjelasan spesifik secara logika (bersumber dari skripsi) mengapa pilihan tersebut salah.
6. Gunakan Bahasa Indonesia yang baik, benar, dan formal.

SYARAT FORMAT OUTPUT (WAJIB JSON):
- Respons Anda harus valid dan bisa langsung di-parse oleh fungsi `json.decode()`.
- Dilarang membungkus JSON dalam blok teks lain.
- Gunakan struktur JSON Array objek seperti contoh di bawah:

[
  {
    "nomorSoal": 1,
    "bab": "Isi nama Bab (Contoh: Bab 1 Pendahuluan)",
    "pertanyaan": "Tulis pertanyaan di sini",
    "pilihanA": "Isi pilihan jawaban A",
    "pilihanB": "Isi pilihan jawaban B",
    "pilihanC": "Isi pilihan jawaban C",
    "pilihanD": "Isi pilihan jawaban D",
    "jawabanBenar": "A",
    "penjelasanBenar": "Pujian dan alasan logis dari skripsi mengapa A benar, serta konsekuensi jika A tidak dipilih...",
    "penjelasanSalahA": "Alasan spesifik dan logis mengapa A salah (kosongkan jika A adalah jawaban benar)",
    "penjelasanSalahB": "Alasan spesifik dan logis mengapa B salah bersumber dari skripsi...",
    "penjelasanSalahC": "Alasan spesifik dan logis mengapa C salah bersumber dari skripsi...",
    "penjelasanSalahD": "Alasan spesifik dan logis mengapa D salah bersumber dari skripsi..."
  }
]

PENTING: JANGAN BERIKAN TEKS APAPUN SEBELUM ATAU SESUDAH BRACKET JSON [ ].''';
  }

  static String buildAnalysisPrompt(List<LatihanHistoryItem> history) {
    // 1. Ambil 10 sesi terbaru
    // 2. Urutkan dari terlama ke terbaru agar AI paham alur progresnya
    final recentHistory = history.take(10).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final historyData = recentHistory.map((h) => 
      "- Tgl: ${h.date.day}/${h.date.month}, Skor: ${h.score}, Level: ${h.settings.levelLabel}, Bab: ${h.settings.babDipilih.join(',')}, Soal: ${h.totalQuestions}"
    ).join("\n");

    return '''KAMU ADALAH MENTOR SKRIPSI CERDAS.
Tugas: Berikan analisis singkat dan motivasi berdasarkan riwayat latihan mahasiswa berikut:

DATA RIWAYAT (10 Sesi Terakhir):
$historyData

SYARAT ANALISIS:
1. Singkat (maksimal 3-4 kalimat).
2. Analisis tren (apakah membaik/memburuk).
3. Berikan saran spesifik (misal: "fokus lagi di level 2 bab 3" atau "pertahankan konsistensi").
4. Gunakan nada bicara penyemangat tapi tetap kritis jika nilai rendah.
5. Gunakan Bahasa Indonesia yang natural.

Output: Langsung berikan teks analisis tanpa embel-embel lain.''';
  }
}
