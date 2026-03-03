// konfigurasi koneksi ke backend api.
// otomatis pilih url berdasarkan platform: web pakai localhost,
// mobile pakai ip jaringan lokal atau url production.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConfig {
  // batas waktu http request ke backend (dalam detik)
  static const int timeoutSeconds = 60;

  // jumlah retry kalau request gagal karena masalah jaringan
  static const int maxRetries = 2;

  // jeda antar retry (dalam milidetik)
  static const int retryDelayMs = 1500;

  // url development untuk web
  static const String _webDevUrl = 'http://localhost:8000';

  // url development untuk mobile (sesuaikan ip lokal)
  static const String _mobileDevUrl = 'http://192.168.0.105:8000';

  // url production (ganti saat deployment)
  // ignore: unused_field
  static const String _productionUrl = 'http://192.168.0.110:8000';

  // base url dipilih otomatis berdasarkan platform
  static String get baseUrl => kIsWeb ? _webDevUrl : _mobileDevUrl;

  // endpoint tanya jawab utama
  static String get askEndpoint => '$baseUrl/api/ask';

  // endpoint health check
  static String get healthEndpoint => '$baseUrl/health';
}
