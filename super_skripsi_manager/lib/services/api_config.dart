class ApiConfig {
  // Google OAuth Credentials
  static const String googleClientId = '70968009073-poje842t16nelot0pu62kp3l400ju2e7.apps.googleusercontent.com';
  static const String googleClientSecret = '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';

  // Academic Search Keys
  static const String semanticScholarKey = ''; // Deprecated
  static const String coreApiKey = 'SsBYVZwqjx9WvGCQ7lTp2nEyguHNRa5F';

  // API Scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
  ];
}
