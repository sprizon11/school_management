class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://school-management-692069213021.asia-south1.run.app/api',
  );

  /// Google OAuth **web** client ID, used as `serverClientId` so the ID token's
  /// audience matches what the backend verifies (GOOGLE_CLIENT_IDS). Supplied at
  /// build time: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. Empty = disabled.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get googleSignInEnabled => googleServerClientId.isNotEmpty;
}
