import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// exception khusus untuk error dari NlpService supaya
// viewmodel bisa kasih pesan error yang spesifik ke ui
class NlpException implements Exception {
  final String message;
  final int? statusCode;
  const NlpException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// exception saat request dibatalkan oleh pengguna
class NlpCancelledException implements Exception {
  const NlpCancelledException();
}

// service untuk komunikasi dengan backend rag api.
// otomatis kirim firebase auth token, ada retry untuk masalah jaringan,
// timeout supaya ui tidak freeze, dan error handling per status code.
class NlpService {
  final String baseUrl;

  NlpService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  // ambil firebase id token dari user yang sedang login
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  // kirim pertanyaan ke backend dan terima jawaban rag.
  // bisa terima client opsional untuk mendukung pembatalan request.
  Future<Map<String, dynamic>> getAnswerFromVectorDB(
    String query, {
    int topK = 3,
    http.Client? client,
  }) async {
    final url = Uri.parse('${baseUrl}/api/ask');
    final effectiveClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    // bangun headers dengan auth token
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

    // ulangi request kalau gagal karena jaringan
    http.Response? response;
    Exception? lastError;

    for (int attempt = 0; attempt <= ApiConfig.maxRetries; attempt++) {
      try {
        response = await effectiveClient
            .post(url, headers: headers, body: body)
            .timeout(Duration(seconds: ApiConfig.timeoutSeconds));
        break; // berhasil, keluar dari loop
      } on http.ClientException {
        // client ditutup (dibatalkan oleh user)
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

      // tunggu sebelum retry (kecuali percobaan terakhir)
      if (attempt < ApiConfig.maxRetries) {
        await Future.delayed(
          Duration(milliseconds: ApiConfig.retryDelayMs),
        );
      }
    }

    // tutup client kalau kita yang buat
    if (shouldCloseClient) effectiveClient.close();

    // kalau semua retry gagal
    if (response == null) {
      throw lastError ?? const NlpException('Gagal menghubungi server.');
    }

    // parse response berdasarkan status code
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