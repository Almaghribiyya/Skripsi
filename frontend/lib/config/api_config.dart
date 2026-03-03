// konfigurasi koneksi ke backend api.
// mode production: ubah isProduction ke true dan isi _productionUrl.
// mode development: otomatis pilih url berdasarkan platform.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConfig {
  // mode production: ubah ke true saat deployment
  static const bool isProduction = false;

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

  // TODO: ganti dengan domain atau IP server production sebenarnya
  static const String _productionUrl = 'https://api.example.com';

  // base url dipilih berdasarkan mode dan platform
  static String get baseUrl {
    if (isProduction) return _productionUrl;
    return kIsWeb ? _webDevUrl : _mobileDevUrl;
  }

  // endpoint tanya jawab utama
  static String get askEndpoint => '$baseUrl/api/ask';

  // endpoint health check
  static String get healthEndpoint => '$baseUrl/health';
}
