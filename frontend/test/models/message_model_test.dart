// test untuk model data: VerseReference, MessageModel, ChatSession.
// verifikasi serialisasi json (fromJson/toJson) dan edge case.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/message_model.dart';

void main() {
  // ---------- VerseReference ----------

  group('VerseReference', () {
    test('fromJson membuat objek dengan benar', () {
      final json = {
        'surah': 'Al-Fatihah',
        'ayat': '1',
        'teks_arab': 'بسم الله الرحمن الرحيم',
        'terjemahan': 'Dengan nama Allah Yang Maha Pengasih',
      };
      final ref = VerseReference.fromJson(json);

      expect(ref.surahName, 'Al-Fatihah');
      expect(ref.ayatNumber, '1');
      expect(ref.arabicText, 'بسم الله الرحمن الرحيم');
      expect(ref.translation, 'Dengan nama Allah Yang Maha Pengasih');
    });

    test('fromJson field kosong jadi string kosong', () {
      final ref = VerseReference.fromJson({});

      expect(ref.surahName, '');
      expect(ref.ayatNumber, '');
      expect(ref.arabicText, '');
      expect(ref.translation, '');
    });

    test('fromJson ayat int dikonversi ke string', () {
      final ref = VerseReference.fromJson({'ayat': 5});
      expect(ref.ayatNumber, '5');
    });

    test('toJson round-trip', () {
      final original = VerseReference(
        surahName: 'Al-Baqarah',
        ayatNumber: '255',
        arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
        translation: 'Allah, tidak ada tuhan selain Dia',
      );
      final json = original.toJson();
      final restored = VerseReference.fromJson(json);

      expect(restored.surahName, original.surahName);
      expect(restored.ayatNumber, original.ayatNumber);
      expect(restored.arabicText, original.arabicText);
      expect(restored.translation, original.translation);
    });
  });

  // ---------- MessageModel ----------

  group('MessageModel', () {
    test('fromJson user message', () {
      final json = {
        'id': 'msg-1',
        'text': 'Apa itu iman?',
        'sender': 'user',
        'timestamp': 1700000000000,
      };
      final msg = MessageModel.fromJson(json);

      expect(msg.id, 'msg-1');
      expect(msg.text, 'Apa itu iman?');
      expect(msg.sender, MessageSender.user);
      expect(msg.timestamp.millisecondsSinceEpoch, 1700000000000);
      expect(msg.verseReferences, isNull);
    });

    test('fromJson ai message with references', () {
      final json = {
        'id': 'msg-2',
        'text': 'Iman adalah percaya...',
        'sender': 'ai',
        'timestamp': 1700000001000,
        'verseReferences': [
          {
            'surah': 'Al-Baqarah',
            'ayat': '3',
            'teks_arab': 'الَّذِينَ يُؤْمِنُونَ بِالْغَيْبِ',
            'terjemahan': 'Yaitu mereka yang beriman kepada yang gaib',
          }
        ],
      };
      final msg = MessageModel.fromJson(json);

      expect(msg.sender, MessageSender.ai);
      expect(msg.verseReferences, isNotNull);
      expect(msg.verseReferences!.length, 1);
      expect(msg.verseReferences![0].surahName, 'Al-Baqarah');
    });

    test('fromJson field kosong defaults', () {
      final msg = MessageModel.fromJson({});

      expect(msg.id, '');
      expect(msg.text, '');
      expect(msg.sender, MessageSender.user); // default bukan 'ai'
      expect(msg.verseReferences, isNull);
    });

    test('toJson round-trip tanpa referensi', () {
      final original = MessageModel(
        id: 'test-id',
        text: 'Apa arti sabar?',
        sender: MessageSender.user,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final json = original.toJson();
      final restored = MessageModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.sender, original.sender);
      expect(restored.timestamp.millisecondsSinceEpoch,
          original.timestamp.millisecondsSinceEpoch);
    });

    test('toJson round-trip dengan referensi', () {
      final original = MessageModel(
        id: 'test-ai',
        text: 'Sabar berarti...',
        sender: MessageSender.ai,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        verseReferences: [
          VerseReference(
            surahName: 'Al-Baqarah',
            ayatNumber: '153',
            arabicText: 'يا أيها الذين آمنوا استعينوا بالصبر',
            translation: 'Wahai orang-orang yang beriman',
          ),
        ],
      );
      final json = original.toJson();
      final restored = MessageModel.fromJson(json);

      expect(restored.verseReferences, isNotNull);
      expect(restored.verseReferences!.length, 1);
      expect(restored.verseReferences![0].surahName, 'Al-Baqarah');
      expect(restored.verseReferences![0].ayatNumber, '153');
    });

    test('sender encoding: user → "user", ai → "ai"', () {
      final userMsg = MessageModel(
        id: '1',
        text: 'test',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );
      final aiMsg = MessageModel(
        id: '2',
        text: 'test',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );

      expect(userMsg.toJson()['sender'], 'user');
      expect(aiMsg.toJson()['sender'], 'ai');
    });
  });

  // ---------- ChatSession ----------

  group('ChatSession', () {
    test('constructor default', () {
      final session = ChatSession(
        id: 'session-1',
        title: 'Obrolan Baru',
        createdAt: DateTime.now(),
      );

      expect(session.messages, isEmpty);
    });

    test('fromJson lengkap', () {
      final json = {
        'id': 's1',
        'title': 'Tentang Sabar',
        'createdAt': 1700000000000,
        'messages': [
          {
            'id': 'm1',
            'text': 'Apa itu sabar?',
            'sender': 'user',
            'timestamp': 1700000000000,
          },
          {
            'id': 'm2',
            'text': 'Sabar adalah...',
            'sender': 'ai',
            'timestamp': 1700000001000,
          },
        ],
      };
      final session = ChatSession.fromJson(json);

      expect(session.id, 's1');
      expect(session.title, 'Tentang Sabar');
      expect(session.messages.length, 2);
      expect(session.messages[0].sender, MessageSender.user);
      expect(session.messages[1].sender, MessageSender.ai);
    });

    test('fromJson tanpa messages default kosong', () {
      final session = ChatSession.fromJson({
        'id': 's2',
        'createdAt': 1700000000000,
      });

      expect(session.messages, isEmpty);
      expect(session.title, 'Obrolan Baru'); // default
    });

    test('toJson round-trip', () {
      final original = ChatSession(
        id: 'session-rt',
        title: 'Round Trip',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        messages: [
          MessageModel(
            id: 'm1',
            text: 'Hello',
            sender: MessageSender.user,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        ],
      );
      final json = original.toJson();
      final restored = ChatSession.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.messages.length, 1);
      expect(restored.messages[0].text, 'Hello');
      expect(restored.createdAt.millisecondsSinceEpoch,
          original.createdAt.millisecondsSinceEpoch);
    });

    test('title bisa diubah (mutable)', () {
      final session = ChatSession(
        id: 's3',
        title: 'Awal',
        createdAt: DateTime.now(),
      );
      session.title = 'Baru';
      expect(session.title, 'Baru');
    });

    test('messages bisa ditambah langsung (mutable list)', () {
      final session = ChatSession(
        id: 's4',
        title: 'Test',
        createdAt: DateTime.now(),
      );
      session.messages.add(MessageModel(
        id: 'mx',
        text: 'Added',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      expect(session.messages.length, 1);
    });
  });
}
