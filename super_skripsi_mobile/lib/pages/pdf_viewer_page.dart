import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/glassmorphism_theme.dart';

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GlassmorphismTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GlassmorphismTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'PDF Viewer',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: GlassmorphismTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: GlassmorphismTheme.textPrimary),
            onPressed: () => _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, color: GlassmorphismTheme.textPrimary),
            onPressed: () => _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25,
          ),
        ],
      ),
      body: SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        key: _pdfViewerKey,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat PDF: ${details.error}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}
