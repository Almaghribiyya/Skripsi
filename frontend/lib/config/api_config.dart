/// Konfigurasi terpusat untuk koneksi API backend.
///
/// Menggunakan pattern kIsWeb untuk otomatis memilih URL yang tepat:
/// - Web: localhost (same-origin)
/// - Mobile: IP jaringan lokal / production URL
///
/// Untuk production, ganti [_productionUrl] dengan URL deployment.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConfig {
  /// Timeout untuk HTTP request ke backend (dalam detik).
  static const int timeoutSeconds = 60;

  /// Jumlah retry jika request gagal karena network error.
  static const int maxRetries = 2;

  /// Delay antar retry (dalam milidetik).
  static const int retryDelayMs = 1500;

  /// Base URL untuk development — Web
  static const String _webDevUrl = 'http://localhost:8000';

  /// Base URL untuk development — Mobile (sesuaikan IP lokal Anda)
  static const String _mobileDevUrl = 'http://192.168.0.110:8000';

  // ignore: unused_field
  /// Base URL untuk production (ganti saat deployment)
  static const String _productionUrl = 'http://192.168.0.110:8000';

  /// Base URL yang digunakan, ditentukan otomatis berdasarkan platform.
  static String get baseUrl => kIsWeb ? _webDevUrl : _mobileDevUrl;

  /// Endpoint Q&A utama.
  static String get askEndpoint => '$baseUrl/api/ask';

  /// Endpoint health check.
  static String get healthEndpoint => '$baseUrl/health';
}
