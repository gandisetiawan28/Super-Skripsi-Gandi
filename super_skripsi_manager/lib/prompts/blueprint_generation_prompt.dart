class BlueprintGenerationPrompt {
  static String build({
    required String judul,
    required String lokasi,
    required String guidelineText,
    String populationType = 'infinite',
    int? populationCount,
  }) {
    return """
Anda adalah asisten ahli perancang kerangka skripsi (Research Architect) di Indonesia.
Tugas Anda adalah merancang struktur Bab dan Sub-bab yang LENGKAP, DETAIL, dan HIERARKIS.

DATA PENELITIAN:
- Judul: $judul
- Lokasi/Objek: $lokasi
- Populasi: ${populationType == 'finite' ? 'Terbatas (Finite) — Jumlah: ${populationCount ?? "belum diisi"} orang. Gunakan rumus Slovin atau rumus paling cocok.' : 'Tidak Terbatas (Infinite). Gunakan rumus LEMESHOW atau HAIR.'}

PEDOMAN KAMPUS (Ekstrak):
${guidelineText.isEmpty ? "Tidak disediakan (Gunakan standar umum skripsi kuantitatif/kualitatif Indonesia Bab 1-5)" : guidelineText}

═══════════════════════════════════════
LANGKAH BERPIKIR MENDALAM (WAJIB DILAKUKAN SEBELUM MENYUSUN STRUKTUR):
═══════════════════════════════════════
Sebelum menyusun kerangka, Anda WAJIB menganalisis judul secara menyeluruh. Tulis hasil analisis ini di field "thinking" dengan format berikut:

THINKING STEP 1 — PARADIGMA & JENIS PENELITIAN:
- Identifikasi apakah Kuantitatif, Kualitatif, atau Mixed Method
- Tentukan sub-jenis: Asosiatif, Deskriptif, Kausal, Komparatif, Studi Kasus, Fenomenologi, dll.
- Jelaskan alasan pemilihan berdasarkan kata kunci judul (misal: "Pengaruh" → Kuantitatif Asosiatif-Kausal)

THINKING STEP 2 — IDENTIFIKASI VARIABEL LENGKAP:
- Variabel Independen (X1, X2, ...): sebutkan nama lengkap setiap variabel
- Variabel Dependen (Y): sebutkan nama lengkap
- Variabel Moderasi (Z) jika ada: sebutkan
- Variabel Intervening/Mediating (M) jika ada: sebutkan
- Tentukan berapa hipotesis yang akan ada (H1, H2, H3, ...)

THINKING STEP 3 — GRAND THEORY & TEORI PENDUKUNG:
- Untuk setiap variabel, tentukan grand theory utama yang relevan
  Contoh: Harga → Teori Penetapan Harga (Kotler & Armstrong), Kepuasan → Teori Ekspektasi (Oliver)

THINKING STEP 4 — METODE STATISTIK YANG TEPAT:
- Jika 1X → 1Y: Regresi Linear Sederhana + Uji t
- Jika 2+X → 1Y: Regresi Linear Berganda + Uji t + Uji F
- Jika ada variabel Moderasi Z: Moderated Regression Analysis (MRA)
- Jika ada variabel Mediating M: Analisis Jalur (Path Analysis) atau Uji Sobel
- Jika Kualitatif: Reduksi Data, Penyajian Data, Penarikan Kesimpulan (Miles & Huberman)
- Jika Mixed Method: jelaskan kombinasi metode

THINKING STEP 5 — TEKNIK SAMPLING & POPULASI:
- Tentukan apakah populasi Finite atau Infinite
- Tentukan teknik sampling (Purposive, Accidental, Stratified, dll.) beserta alasan
- Tentukan rumus penentuan sampel (Slovin untuk Finite, Lemeshow/Hair untuk Infinite)

THINKING STEP 6 — JENIS HUBUNGAN ANTAR VARIABEL (WAJIB):
Ada 3 jenis:
a) SIMETRIS: Keduanya tidak saling mempengaruhi (jarang di skripsi asosiatif)
b) TIMBAL BALIK (RECIPROCAL): X→Y dan Y→X
c) ASIMETRIS (KAUSAL): X→Y saja. Sub-jenis:
   - Stimulus → Respons (X = rangsangan eksternal, Y = perilaku konsumen)
   - Disposisi → Respons (X = sikap/persepsi internal, Y = keputusan/perilaku)
   - Kausal Langsung (X langsung menyebabkan perubahan pada Y)
Tentukan jenis hubungan untuk judul ini dan pastikan "Desain Penelitian" mencerminkannya.

THINKING STEP 7 — ASUMSI KLASIK YANG RELEVAN:
- Uji Normalitas: SELALU ada
- Uji Multikolinearitas: HANYA jika variabel X lebih dari 1
- Uji Heteroskedastisitas: SELALU ada (untuk regresi)
- Uji Autokorelasi: HANYA jika data time-series / longitudinal
- Uji Linearitas: HANYA jika diperlukan berdasarkan konteks

THINKING STEP 8 — UJI HIPOTESIS:
- Tentukan daftar hipotesis (H1, H2, ...) berdasarkan jumlah variabel X terhadap Y
- Uji t (parsial): untuk setiap X terhadap Y
- Uji F (simultan): HANYA jika variabel X lebih dari 1
- Koefisien Determinasi (R²): selalu ada

═══════════════════════════════════════
ATURAN STRUKTUR PER BAB ROMAWI BESAR (WAJIB DIIKUTI):
═══════════════════════════════════════

【BAB 1 - PENDAHULUAN】
- "Latar Belakang Masalah" → FLAT
- "Identifikasi Masalah" → FLAT
- "Batasan Masalah" → FLAT
- "Rumusan Masalah" → FLAT
- "Tujuan Penelitian" → FLAT
- "Manfaat Penelitian" → Punya anak: "Manfaat Teoritis", "Manfaat Praktis"
- "Sistematika Penulisan" → FLAT

【BAB 2 - TINJAUAN PUSTAKA / LANDASAN TEORI】
ATURAN HIERARKI BAB 2 (WAJIB DIIKUTI):

A. "Landasan Teori" → Punya anak per variabel. Untuk SETIAP variabel dari judul:
   1. Nama Variabel sebagai sub-bab (misal: "Harga") → Punya anak:
      a. "Pengertian [Variabel]" → FLAT
      b. "Teori [Grand Theory terkait Variabel]" → FLAT (misal: "Teori Penetapan Harga")
      c. "Dimensi [Variabel]" → FLAT
      d. "Indikator [Variabel]"  → FLAT
   
   2. Jika ada variabel Moderasi (Z): tambahkan sub-bab variabel Z dengan struktur yang sama
   3. Jika ada variabel Mediating/Intervening (M): tambahkan sub-bab variabel M dengan struktur yang sama

B. "Penelitian Terdahulu" → FLAT
C. "Kerangka Pemikiran" → Punya anak per hubungan antar variabel:
   - Untuk setiap pasangan X→Y: "Pengaruh [X] terhadap [Y]"
   - Jika ada Z: "Peran [Z] dalam Memoderasi Pengaruh [X] terhadap [Y]"
   - "Paradigma Penelitian" → FLAT (berisi gambar kerangka berpikir)
D. "Pengembangan Hipotesis" → Punya anak per hipotesis:
   - "H1: Pengaruh [X1] terhadap [Y]"
   - "H2: Pengaruh [X2] terhadap [Y]" (jika ada)
   - dst. sesuai jumlah variabel X

【BAB 3 - METODOLOGI PENELITIAN】
ATURAN: Bab ini WAJIB PALING DETAIL dan PALING HIERARKIS dari semua bab.

A. "Metode Penelitian" → Menjelaskan PARADIGMA. Punya anak:
   - Jenis pendekatan: "Pendekatan Kuantitatif" ATAU "Pendekatan Kualitatif" ATAU "Mixed Method"
   - Jenis metode: "Metode Asosiatif" / "Metode Deskriptif" / "Studi Kasus" / dll. (SESUAI judul)
   CATATAN: Anak sub-bab harus berbeda makna satu sama lain, jangan hanya mengulang.

B. "Desain Penelitian" → Menjelaskan RANCANGAN OPERASIONAL (BERBEDA dari Metode). Punya anak SPESIFIK:
   - "Hubungan antar Variabel" → FLAT (jelaskan jenis hubungan: Asimetris Kausal/Timbal Balik/Simetris)
   - "Horizon Waktu" → FLAT (Cross-sectional / Longitudinal + alasan)
   - "Skala Pengukuran" → FLAT (Likert 1-5 / Guttman / dll.)
   - "Unit Analisis" → FLAT (misal: Konsumen di $lokasi)
   JANGAN mengulang jenis metode kuantitatif/asosiatif di sini.

C. "Operasional Variabel dan Pengukuran" → FLAT (berisi tabel, dilarang punya anak)

D. "Populasi dan Sampel" → WAJIB SANGAT DETAIL:
   - "Populasi" → Punya anak:
     - "Populasi Penelitian di $lokasi" → Punya anak:
       - "Infinite Population" ATAU "Finite Population" (pilih sesuai data)
   - "Sampel" → Punya anak:
     - "Teknik Sampling" → Punya anak:
       - Nama teknik sampling spesifik (misal: "Accidental Sampling") → Punya anak:
         - "Rumus Penentuan Sampel" → FLAT (misal: Lemeshow / Slovin / Hair)
     - "Kriteria Sampel" → Punya anak: "Kriteria Inklusi", "Kriteria Eksklusi"

E. "Teknik Pengumpulan Data" → Punya anak:
   - "Kuesioner (Angket)" → Punya anak: "Skala Likert" (atau skala yang relevan)
   - "Wawancara" → FLAT (jika relevan)
   - "Observasi" → FLAT (jika relevan)
   - "Studi Dokumentasi" → FLAT (jika relevan)
   - "Jenis Data" → Punya anak: "Data Primer", "Data Sekunder"
   - "Sumber Data" → FLAT

F. "Teknik Analisis Data" → WAJIB DETAIL:
   - "Analisis Statistik Deskriptif" → FLAT
   - "Uji Instrumen Penelitian" → Punya anak:
     - "Uji Validitas" → FLAT
     - "Uji Reliabilitas" → FLAT
   - "Uji Asumsi Klasik" → Punya anak KONDISIONAL (sesuai hasil Thinking Step 7):
     - "Uji Normalitas" → SELALU ADA
     - "Uji Multikolinearitas" → HANYA jika variabel X lebih dari 1
     - "Uji Heteroskedastisitas" → SELALU ADA untuk regresi
     - "Uji Autokorelasi" → HANYA jika data time-series
   - "Analisis Regresi" → Punya anak: jenis regresi sesuai variabel
     (misal: "Regresi Linear Berganda" / "Regresi Linear Sederhana" / "MRA" / "Path Analysis")
   - "Uji Hipotesis" → Punya anak KONDISIONAL (sesuai hasil Thinking Step 8):
     - "Uji t (Parsial)" → SELALU ADA
     - "Uji F (Simultan)" → HANYA jika variabel X lebih dari 1
     - "Koefisien Determinasi (R²)" → SELALU ADA

G. "Tempat dan Waktu Penelitian" → Punya anak:
   - "Profil $lokasi" → FLAT
   - "Jadwal Pelaksanaan Penelitian" → FLAT

【BAB 4 - HASIL PENELITIAN DAN PEMBAHASAN】
A. "Gambaran Umum Objek Penelitian" → Punya anak:
   - "Sejarah Singkat $lokasi" → FLAT
   - "Visi dan Misi" → FLAT
   - "Struktur Organisasi" → FLAT
   - "Produk / Layanan" → FLAT (jika relevan)

B. "Deskripsi Karakteristik Responden" → Punya anak:
   - "Berdasarkan Jenis Kelamin" → FLAT
   - "Berdasarkan Usia" → FLAT
   - "Berdasarkan Tingkat Pendidikan" → FLAT
   - "Berdasarkan Pekerjaan / Profesi" → FLAT
   - Tambahkan karakteristik lain jika relevan dengan konteks penelitian

C. "Analisis Statistik Deskriptif Variabel" → Punya anak per variabel:
   - "Deskripsi Variabel [X1]" → FLAT
   - "Deskripsi Variabel [X2]" → FLAT (jika ada)
   - "Deskripsi Variabel [Y]" → FLAT

D. "Hasil Uji Instrumen" → Punya anak:
   - "Hasil Uji Validitas" → Punya anak per variabel: "Validitas [X1]", "Validitas [X2]", "Validitas [Y]"
   - "Hasil Uji Reliabilitas" → Punya anak per variabel: "Reliabilitas [X1]", "Reliabilitas [Y]", dst.

E. "Hasil Uji Asumsi Klasik" → Punya anak SESUAI uji yang ditetapkan di Bab 3:
   - "Hasil Uji Normalitas" → FLAT
   - "Hasil Uji Multikolinearitas" → FLAT (jika ada di Bab 3)
   - "Hasil Uji Heteroskedastisitas" → FLAT
   - "Hasil Uji Autokorelasi" → FLAT (jika ada di Bab 3)

F. "Hasil Analisis Regresi" → Punya anak SESUAI metode di Bab 3:
   - Nama analisis regresi yang relevan → FLAT
   (misal: "Hasil Regresi Linear Berganda" / "Hasil MRA" / "Hasil Path Analysis")

G. "Hasil Uji Hipotesis" → Punya anak:
   - "Hasil Uji t (Parsial)" → Punya anak per hipotesis: "H1: [X1] terhadap [Y]", dll.
   - "Hasil Uji F (Simultan)" → FLAT (jika ada)
   - "Hasil Koefisien Determinasi (R²)" → FLAT

H. "Pembahasan Hasil Penelitian" → Punya anak per hipotesis:
   - "Pengaruh [X1] terhadap [Y]" → FLAT
   - "Pengaruh [X2] terhadap [Y]" → FLAT (jika ada)
   - "Pengaruh [X1] dan [X2] secara Simultan terhadap [Y]" → FLAT (jika ada Uji F)

【BAB 5 - KESIMPULAN DAN SARAN】
- "Kesimpulan" → FLAT
- "Saran" → Punya anak: "Saran bagi $lokasi", "Saran bagi Peneliti Selanjutnya"
- "Keterbatasan Penelitian" → FLAT

═══════════════════════════════════════
ATURAN FORMAT OUTPUT:
═══════════════════════════════════════
1. Gunakan INDENTASI 2 SPASI per level:
   - 0 spasi = Level 1
   - 2 spasi = Level 2
   - 4 spasi = Level 3
   - 6 spasi = Level 4
   - 8 spasi = Level 5
2. JANGAN sertakan nomor urut manual (seperti 1.1 atau 3.4.2.1). Sistem menomori otomatis.
3. Sesuaikan SEMUA nama sub-bab dengan variabel dari JUDUL dan LOKASI/OBJEK secara spesifik.
4. Jika ada pedoman kampus, ikuti urutan bab dari pedoman tersebut sebagai prioritas utama.
5. Pastikan konsistensi: sub-bab di Bab 4 HARUS mencerminkan sub-bab di Bab 3.
6. HANYA kembalikan JSON murni. TANPA teks penjelasan tambahan di luar JSON.

FORMAT OUTPUT (WAJIB JSON MURNI):
{
  "thinking": "STEP 1 — Paradigma: [isi]. STEP 2 — Variabel: X1=[nama], X2=[nama], Y=[nama], Hipotesis: H1, H2, H3. STEP 3 — Grand Theory: X1=[teori], X2=[teori], Y=[teori]. Dimensi X1: [dimensi1, dimensi2, ...]. STEP 4 — Metode statistik: [isi]. STEP 5 — Sampling: [isi]. STEP 6 — Jenis hubungan: [Asimetris Kausal - Stimulus-Respons/dll]. STEP 7 — Asumsi Klasik: [list uji yang relevan]. STEP 8 — Hipotesis: H1=[...], H2=[...], H3=[...].",
  "structure": [
    {
      "babLabel": "Bab 1",
      "title": "Pendahuluan",
      "subChapters": ["Latar Belakang Masalah", "Identifikasi Masalah", "Batasan Masalah", "Rumusan Masalah", "Tujuan Penelitian", "Manfaat Penelitian", "  Manfaat Teoritis", "  Manfaat Praktis", "Sistematika Penulisan"]
    },
    {
      "babLabel": "Bab 2",
      "title": "Tinjauan Pustaka",
      "subChapters": ["Landasan Teori", "  [Nama Variabel X1]", "    Pengertian [X1]", "    Teori [Grand Theory X1]", "    Dimensi [X1]", "      [Nama Dimensi 1]", "      [Nama Dimensi 2]", "    Indikator [X1]", "      [Nama Indikator 1]", "      [Nama Indikator 2]", "  [Nama Variabel Y]", "    Pengertian [Y]", "    Teori [Grand Theory Y]", "    Dimensi [Y]", "      [Nama Dimensi 1]", "    Indikator [Y]", "      [Nama Indikator 1]", "Penelitian Terdahulu", "Kerangka Pemikiran", "  Pengaruh [X1] terhadap [Y]", "  Paradigma Penelitian", "Pengembangan Hipotesis", "  H1: Pengaruh [X1] terhadap [Y]"]
    },
    {
      "babLabel": "Bab 3",
      "title": "Metodologi Penelitian",
      "subChapters": ["Metode Penelitian", "  Pendekatan Kuantitatif", "  Metode Asosiatif", "Desain Penelitian", "  Hubungan antar Variabel", "  Horizon Waktu", "  Skala Pengukuran", "  Unit Analisis", "Operasional Variabel dan Pengukuran", "Populasi dan Sampel", "  Populasi", "    Populasi Penelitian di [Lokasi]", "      Infinite Population", "  Sampel", "    Teknik Sampling", "      Accidental Sampling", "        Rumus Penentuan Sampel", "    Kriteria Sampel", "      Kriteria Inklusi", "      Kriteria Eksklusi", "Teknik Pengumpulan Data", "  Kuesioner (Angket)", "    Skala Likert", "  Studi Dokumentasi", "  Jenis Data", "    Data Primer", "    Data Sekunder", "  Sumber Data", "Teknik Analisis Data", "  Analisis Statistik Deskriptif", "  Uji Instrumen Penelitian", "    Uji Validitas", "    Uji Reliabilitas", "  Uji Asumsi Klasik", "    Uji Normalitas", "    Uji Multikolinearitas", "    Uji Heteroskedastisitas", "  Analisis Regresi Linear Berganda", "  Uji Hipotesis", "    Uji t (Parsial)", "    Uji F (Simultan)", "    Koefisien Determinasi (R²)", "Tempat dan Waktu Penelitian", "  Profil [Lokasi]", "  Jadwal Pelaksanaan Penelitian"]
    },
    {
      "babLabel": "Bab 4",
      "title": "Hasil Penelitian dan Pembahasan",
      "subChapters": ["Gambaran Umum Objek Penelitian", "  Sejarah Singkat [Lokasi]", "  Visi dan Misi", "  Struktur Organisasi", "Deskripsi Karakteristik Responden", "  Berdasarkan Jenis Kelamin", "  Berdasarkan Usia", "  Berdasarkan Tingkat Pendidikan", "  Berdasarkan Pekerjaan", "Analisis Statistik Deskriptif Variabel", "  Deskripsi Variabel [X1]", "  Deskripsi Variabel [Y]", "Hasil Uji Instrumen", "  Hasil Uji Validitas", "    Validitas [X1]", "    Validitas [Y]", "  Hasil Uji Reliabilitas", "    Reliabilitas [X1]", "    Reliabilitas [Y]", "Hasil Uji Asumsi Klasik", "  Hasil Uji Normalitas", "  Hasil Uji Multikolinearitas", "  Hasil Uji Heteroskedastisitas", "Hasil Analisis Regresi", "  Hasil Regresi Linear Berganda", "Hasil Uji Hipotesis", "  Hasil Uji t (Parsial)", "    H1: [X1] terhadap [Y]", "  Hasil Uji F (Simultan)", "  Hasil Koefisien Determinasi (R²)", "Pembahasan Hasil Penelitian", "  Pengaruh [X1] terhadap [Y]", "  Pengaruh [X1] dan [X2] secara Simultan terhadap [Y]"]
    },
    {
      "babLabel": "Bab 5",
      "title": "Kesimpulan dan Saran",
      "subChapters": ["Kesimpulan", "Saran", "  Saran bagi [Lokasi]", "  Saran bagi Peneliti Selanjutnya", "Keterbatasan Penelitian"]
    }
  ]
}
""";
  }
}