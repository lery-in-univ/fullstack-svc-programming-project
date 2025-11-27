class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration pollingInterval = Duration(seconds: 1);
  static const int maxPollingAttempts = 60;
  static const Duration sessionRenewInterval = Duration(minutes: 8); // TTL 10분, 여유 2분
}
