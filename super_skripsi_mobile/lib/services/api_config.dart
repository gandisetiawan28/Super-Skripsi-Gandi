class ApiConfig {
  // Google OAuth Credentials
  static const String googleClientId = '70968009073-o8ioobnhcgl2co3bqp87rcrvv7tbbjgo.apps.googleusercontent.com';
  static const String googleClientSecret = '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';

  // Academic Search Keys
  static const String semanticScholarKey = ''; // Deprecated
  static const String coreApiKey = 'SsBYVZwqjx9WvGCQ7lTp2nEyguHNRa5F';

  // Cloud RAG URL (VPS / Server Backend)
  // Untuk mobile, kita tidak bisa menggunakan localhost, harus menggunakan IP/Domain server.
  static const String ragCloudUrl = 'http://your-vps-ip:28146'; 

  // API Scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
  ];
}
