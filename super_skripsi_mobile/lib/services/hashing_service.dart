import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashingService {
  /// Generate MD5 hash from text content
  String generateHash(String textContent) {
    final bytes = utf8.encode(textContent);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if a hash already exists in the provided set
  bool isDuplicate(String hash, Set<String> existingHashes) {
    return existingHashes.contains(hash);
  }
}
