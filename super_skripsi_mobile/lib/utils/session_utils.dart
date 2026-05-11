class SessionUtils {
  static String getSafeEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'default';
    }
    return email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  static String getDynamicBoxName(String baseName, String? email) {
    return '${baseName}_${getSafeEmail(email)}';
  }
}
