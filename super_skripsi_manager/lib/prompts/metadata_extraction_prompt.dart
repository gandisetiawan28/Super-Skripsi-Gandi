/// prompts/metadata_extraction_prompt.dart
/// ==========================================
/// Prompt untuk mengekstrak metadata bibliografi dari teks PDF.
/// Digunakan oleh: ai_extraction_service.dart (fitur auto-rename & RIS generation)
///
/// Tips mengedit:
///   - Prompt ini dikirim langsung ke LLM sebagai satu-satunya instruksi.
///   - Output yang diharapkan adalah JSON object tunggal (bukan array).
///   - Placeholder `\$excerpt` akan diganti oleh teks PDF.
///   - Jangan gunakan markdown code fence di dalam prompt.

class MetadataExtractionPrompt {
  /// Membuat prompt lengkap untuk ekstraksi metadata dokumen.
  /// [excerpt] adalah potongan teks dari PDF yang akan dianalisis.
  static String build(String excerpt) {
    return '''
Kamu adalah seorang Pustakawan Akademik Ahli dan Data Scientist. Tugasmu adalah mengekstrak metadata bibliografi dari teks mentah sebuah dokumen dan merapikannya ke dalam format JSON yang valid.

=== LANGKAH 1: DETEKSI TIPE DOKUMEN ===
Pertama, tentukan tipe dokumen dari pilihan berikut berdasarkan konten teks:
- "JOUR" : Artikel Jurnal Ilmiah (ada nama jurnal, volume, issue, halaman, ISSN/DOI)
- "BOOK" : Buku atau Buku Ajar/Ebook (ada nama penerbit, ISBN, tidak ada nama jurnal)
- "THES" : Skripsi atau Tesis (ada kata "skripsi", "tesis", "disertasi", nama universitas/kampus)
- "CONF" : Prosiding/Makalah Konferensi (ada kata "prosiding", "seminar", "conference")
- "RPRT" : Laporan Penelitian atau Teknis

Masukkan hasil deteksi ke field "document_type".

=== LANGKAH 2: ATURAN EKSTRAKSI BERDASARKAN TIPE ===

Jika document_type = "JOUR":
  - Wajib isi: title, authors, year, journal_name, volume, issue, pages
  - Field khusus buku (publisher, isbn, place_of_publication) → null

Jika document_type = "BOOK":
  - Wajib isi: title, authors, year, publisher, place_of_publication
  - Field jurnal (journal_name, volume, issue, pages) → null
  - isbn: isi jika ditemukan, jika tidak → null

Jika document_type = "THES":
  - Wajib isi: title, authors, year
  - Isi publisher dengan nama universitas/institusi, place_of_publication dengan kota kampus
  - Field jurnal → null

Jika document_type = "CONF":
  - Wajib isi: title, authors, year, journal_name (isi dengan nama prosiding/konferensi), pages
  - Field buku → null

=== LANGKAH 3: ATURAN UMUM ===
1. BERSIHKAN NAMA PENULIS: Hapus gelar (S.E., M.M., Ph.D.), angka, email, dan afiliasi kampus. Ambil murni nama orangnya saja.
2. JIKA DATA TIDAK DITEMUKAN: Gunakan null. Jangan mengarang data.
3. EKSTRAK VARIABEL (category): Ekstrak variabel-variabel penelitian dari judul (Variabel X, Y, Z). Pisahkan dengan koma.
4. TERJEMAHAN BILINGUAL (translated_title & translated_category): Terjemahkan judul dan variabel ke bahasa lawan (Inggris→Indonesia atau Indonesia→Inggris).
5. NAMA FILE APA (suggested_filename): Buat nama file berstandar APA dengan aturan penulis:
   - 1 penulis: "NamaBelakang (Tahun) - Judul.pdf"
   - 2 penulis: "NamaBelakang1 & NamaBelakang2 (Tahun) - Judul.pdf"
   - 3+ penulis: "NamaBelakang1 et al. (Tahun) - Judul.pdf"
   (Contoh: "Sembiring et al. (2024) - Metodologi Penelitian.pdf")

=== FORMAT OUTPUT ===
Keluarkan HANYA JSON murni, tanpa markdown, tanpa penjelasan:
{
  "document_type": "JOUR atau BOOK atau THES atau CONF atau RPRT",
  "title": "Judul Lengkap Dokumen",
  "authors": ["Nama Penulis Satu", "Nama Penulis Dua"],
  "year": "2024",
  "category": "Variabel Penelitian, Variabel Lain",
  "translated_title": "English Translation of Title",
  "translated_category": "English Translation of Variables",
  "journal_name": "Nama Jurnal (null jika BOOK/THES)",
  "volume": "1 (null jika bukan JOUR)",
  "issue": "2 (null jika bukan JOUR)",
  "pages": "10-25 (null jika BOOK)",
  "publisher": "Nama Penerbit atau Universitas (null jika JOUR)",
  "isbn": "978-xxx-xxx (null jika tidak ada)",
  "place_of_publication": "Kota Terbit (null jika JOUR)",
  "suggested_filename": "Penulis (Tahun) - Judul Singkat.pdf"
}

DOCUMENT EXCERPT:
$excerpt
''';
  }
}
