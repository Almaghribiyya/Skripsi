import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Exception khusus untuk error yang berasal dari NlpService
/// agar ViewModel bisa memberikan pesan error yang spesifik ke UI.
class NlpException implements Exception {
  final String message;
  final int? statusCode;
  const NlpException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Exception khusus saat request dibatalkan oleh pengguna.
class NlpCancelledException implements Exception {
  const NlpCancelledException();
}

/// Service untuk berkomunikasi dengan Backend RAG API.
///
/// Fitur:
/// - Otomatis mengirim Firebase Auth token (Authorization header).
/// - Retry mechanism untuk network error (configurable).
/// - Timeout protection agar UI tidak freeze.
/// - Error differentiation (401, 429, 5xx, network).
class NlpService {
  final String baseUrl;

  NlpService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Mengambil Firebase ID Token dari user yang sedang login.
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Mengirim pertanyaan ke backend dan menerima jawaban RAG.
  ///
  /// Accepts an optional [client] for cancellation support.
  /// Throws [NlpException] dengan pesan error yang user-friendly.
  Future<Map<String, dynamic>> getAnswerFromVectorDB(
    String query, {
    int topK = 3,
    http.Client? client,
  }) async {
    final url = Uri.parse('${baseUrl}/api/ask');
    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    // Bangun headers dengan auth token
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = await _getAuthToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = json.encode({
      'pertanyaan': query,
      'top_k': topK,
    });

    // Retry loop untuk network resilience
    http.Response? response;
    Exception? lastError;

    for (int attempt = 0; attempt <= ApiConfig.maxRetries; attempt++) {
      try {
        response = await effectiveClient
            .post(url, headers: headers, body: body)
            .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
        break; // Berhasil, keluar dari loop
      } on http.ClientException {
        // Client ditutup (cancelled oleh user)
        throw const NlpCancelledException();
      } on TimeoutException {
        lastError = const NlpException(
          'Server membutuhkan waktu terlalu lama untuk merespons. '
          'Silakan coba lagi.',
        );
      } on SocketException {
        lastError = const NlpException(
          'Tidak dapat terhubung ke server. '
          'Periksa koneksi internet Anda.',
        );
      } catch (e) {
        if (e is NlpCancelledException) rethrow;
        lastError = NlpException('Terjadi kesalahan jaringan: $e');
      }

      // Tunggu sebelum retry (kecuali attempt terakhir)
      if (attempt < ApiConfig.maxRetries) {
        await Future.delayed(
          Duration(milliseconds: ApiConfig.retryDelayMs),
        );
      }
    }

    // Tutup client jika kita yang buat
    if (shouldCloseClient) effectiveClient.close();

    // Jika semua retry gagal
    if (response == null) {
      throw lastError ?? const NlpException('Gagal menghubungi server.');
    }

    // Parse response berdasarkan status code
    switch (response.statusCode) {
      case 200:
        final data = json.decode(response.body);
        return {
          'answer': data['jawaban_llm'] ?? '',
          'references': data['referensi'] ?? [],
          'skor_tertinggi': data['skor_tertinggi'] ?? 0.0,
        };
      case 401:
        throw const NlpException(
          'Sesi login telah berakhir. Silakan login ulang.',
          statusCode: 401,
        );
      case 429:
        throw const NlpException(
          'Terlalu banyak pertanyaan. Tunggu sebentar lalu coba lagi.',
          statusCode: 429,
        );
      case 422:
        throw const NlpException(
          'Pertanyaan tidak valid. Pastikan pertanyaan minimal 3 karakter.',
          statusCode: 422,
        );
      default:
        throw NlpException(
          'Server mengalami gangguan (${response.statusCode}). '
          'Silakan coba lagi nanti.',
          statusCode: response.statusCode,
        );
    }
  }
}