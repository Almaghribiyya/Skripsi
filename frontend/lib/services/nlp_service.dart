import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class NlpService {
  // Untuk HP fisik: gunakan IP LAN komputer (pastikan 1 jaringan WiFi)
  // Untuk Emulator: gunakan 10.0.2.2
  // Untuk Web/Desktop: gunakan localhost
  final String baseUrl;

  NlpService({String? baseUrl})
      : baseUrl = baseUrl ??
            (kIsWeb ? 'http://localhost:8000' : 'http://192.168.0.110:8000');

  Future<Map<String, dynamic>> getAnswerFromVectorDB(
    String query, {
    int topK = 3,
  }) async {
    final url = Uri.parse('$baseUrl/api/ask');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'pertanyaan': query,
        'top_k': topK,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'answer': data['jawaban_llm'] ?? '',
        'references': data['referensi'] ?? [],
      };
    } else {
      throw Exception(
        'Gagal menghubungi server (${response.statusCode})',
      );
    }
  }
}