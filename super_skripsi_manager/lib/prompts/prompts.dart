/// prompts/
/// =========
/// Folder terpusat untuk semua prompt AI yang digunakan oleh Flutter app.
///
/// Cara pakai:
///   import 'package:super_skripsi_manager/prompts/prompts.dart';
///   ...
///   final prompt = Prompts.metadataExtraction(excerpt);
///   final prompt2 = Prompts.ragExplorerSystem;
library prompts;

export 'metadata_extraction_prompt.dart';
export 'rag_explorer_prompt.dart';
