// test untuk NlpService — verifikasi HTTP response parsing,
// error mapping per status code, retry logic, dan cancellation.
// Firebase auth di-stub supaya test jalan tanpa credentials.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/services/nlp_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late NlpService service;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    // baseUrl diset manual supaya tidak bergantung ApiConfig/Flutter binding
    // authTokenProvider null supaya tidak perlu Firebase initialization
    service = NlpService(
      baseUrl: 'http://test:8000',
      authTokenProvider: () async => null,
    );
  });

  // ---------- Response Parsing ----------

  group('Response 200', () {
    test('parse jawaban dan referensi dari response body', () async {
      final responseBody = json.encode({
        'jawaban_llm': 'Sabar berarti menahan diri...',
        'referensi': [
          {
            'surah': 'Al-Baqarah',
            'ayat': '153',
            'teks_arab': 'arabic-text-placeholder',
            'terjemahan': 'Wahai orang-orang yang beriman',
          },
        ],
        'skor_tertinggi': 0.92,
      });

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await service.getAnswerFromVectorDB(
        'Apa itu sabar?',
        client: mockClient,
      );

      expect(result['answer'], 'Sabar berarti menahan diri...');
      expect((result['references'] as List).length, 1);
      expect(result['skor_tertinggi'], 0.92);
    });

    test('field kosong di response default ke empty', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
          (_) async => http.Response(json.encode({}), 200));

      final result = await service.getAnswerFromVectorDB(
        'Test',
        client: mockClient,
      );

      expect(result['answer'], '');
      expect(result['references'], []);
      expect(result['skor_tertinggi'], 0.0);
    });
  });

  // ---------- Error Status Codes ----------

  group('Error Status Codes', () {
    test('401 throw NlpException dengan pesan login ulang', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
          (_) async => http.Response('Unauthorized', 401));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('login ulang'))),
      );
    });

    test('429 throw NlpException rate limit', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
          (_) async => http.Response('Too Many Requests', 429));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpException>()
            .having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('422 throw NlpException validasi', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
          (_) async => http.Response('Unprocessable Entity', 422));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpException>()
            .having((e) => e.statusCode, 'statusCode', 422)),
      );
    });

    test('500 throw NlpException server error', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', contains('500'))),
      );
    });
  });

  // ---------- Network Errors ----------

  group('Network Errors', () {
    test('ClientException throw NlpCancelledException', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(http.ClientException('Connection closed'));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpCancelledException>()),
      );
    });

    test('TimeoutException throw NlpException setelah retry', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(TimeoutException('timeout'));

      expect(
        () => service.getAnswerFromVectorDB('Test', client: mockClient),
        throwsA(isA<NlpException>()
            .having((e) => e.message, 'message', contains('terlalu lama'))),
      );
    });
  });

  // ---------- Request Body ----------

  group('Request Body', () {
    test('kirim pertanyaan dan top_k dalam body', () async {
      String? capturedBody;

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((inv) async {
        capturedBody = inv.namedArguments[#body] as String;
        return http.Response(
          json.encode({
            'jawaban_llm': 'ok',
            'referensi': [],
            'skor_tertinggi': 0.5,
          }),
          200,
        );
      });

      await service.getAnswerFromVectorDB('Apa itu iman?',
          topK: 5, client: mockClient);

      final parsed = json.decode(capturedBody!);
      expect(parsed['pertanyaan'], 'Apa itu iman?');
      expect(parsed['top_k'], 5);
      expect(parsed.containsKey('riwayat_percakapan'), isFalse);
    });

    test('kirim riwayat_percakapan dalam body jika ada', () async {
      String? capturedBody;

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((inv) async {
        capturedBody = inv.namedArguments[#body] as String;
        return http.Response(
          json.encode({
            'jawaban_llm': 'ok',
            'referensi': [],
            'skor_tertinggi': 0.5,
          }),
          200,
        );
      });

      await service.getAnswerFromVectorDB(
        'Jelaskan lagi',
        client: mockClient,
        chatHistory: [
          {'peran': 'user', 'konten': 'Apa itu sabar?'},
          {'peran': 'ai', 'konten': 'Sabar adalah...'},
        ],
      );

      final parsed = json.decode(capturedBody!);
      expect(parsed['riwayat_percakapan'], isA<List>());
      expect(parsed['riwayat_percakapan'].length, 2);
      expect(parsed['riwayat_percakapan'][0]['peran'], 'user');
    });

    test('chatHistory kosong tidak dikirim', () async {
      String? capturedBody;

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((inv) async {
        capturedBody = inv.namedArguments[#body] as String;
        return http.Response(
          json.encode({
            'jawaban_llm': 'ok',
            'referensi': [],
            'skor_tertinggi': 0.5,
          }),
          200,
        );
      });

      await service.getAnswerFromVectorDB(
        'Test',
        client: mockClient,
        chatHistory: [],
      );

      final parsed = json.decode(capturedBody!);
      expect(parsed.containsKey('riwayat_percakapan'), isFalse);
    });
  });

  // ---------- NlpException ----------

  group('NlpException', () {
    test('toString returns message', () {
      const e = NlpException('Test error', statusCode: 500);
      expect(e.toString(), 'Test error');
    });

    test('statusCode optional', () {
      const e = NlpException('No code');
      expect(e.statusCode, isNull);
    });
  });
}
