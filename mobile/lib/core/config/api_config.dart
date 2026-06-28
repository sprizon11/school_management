class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://school-management-692069213021.asia-south1.run.app/api',
  );
}
