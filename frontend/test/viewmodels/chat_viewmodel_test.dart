// test untuk ChatViewModel — verifikasi logic session CRUD,
// edit/delete/regenerate message, loading state, error handling.
// dependency di-mock supaya tidak perlu Firebase atau server asli.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/viewmodels/chat_viewmodel.dart';
import 'package:frontend/models/message_model.dart';
import 'package:frontend/services/nlp_service.dart';
import 'package:frontend/services/firestore_service.dart';

// mock services supaya ChatViewModel bisa ditest tanpa Firebase
class MockNlpService extends Mock implements NlpService {}

class MockFirestoreService extends Mock implements FirestoreService {}

// fake untuk registerFallbackValue supaya mocktail bisa handle any()
class FakeChatSession extends Fake implements ChatSession {}

void main() {
  late ChatViewModel vm;
  late MockNlpService mockNlp;
  late MockFirestoreService mockFirestore;

  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  setUp(() async {
    mockNlp = MockNlpService();
    mockFirestore = MockFirestoreService();

    // stub firestore calls supaya tidak error (fire-and-forget)
    when(() => mockFirestore.saveChatSession(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockFirestore.deleteChatSession(any(), any()))
        .thenAnswer((_) async {});

    vm = ChatViewModel(
      nlpService: mockNlp,
      firestoreService: mockFirestore,
    );

    // tunggu 5ms supaya createNewSession() berikutnya dapat ID berbeda
    // (ChatViewModel constructor pakai DateTime.now().millisecondsSinceEpoch)
    await Future.delayed(const Duration(milliseconds: 5));
  });

  tearDown(() async {
    // tunggu async operations selesai sebelum dispose
    await Future.delayed(const Duration(milliseconds: 300));
    vm.dispose();
  });

  // ---------- Session CRUD ----------

  group('Session CRUD', () {
    test('constructor membuat satu sesi default', () {
      expect(vm.sessions.length, 1);
      expect(vm.activeSessionId, isNotNull);
      expect(vm.sessions.first.title, 'Obrolan Baru');
    });

    test('createNewSession menambah sesi baru di depan', () {
      final firstId = vm.activeSessionId;
      vm.createNewSession();

      expect(vm.sessions.length, 2);
      expect(vm.activeSessionId, isNot(firstId));
      // sesi baru ada di index 0
      expect(vm.sessions[0].id, vm.activeSessionId);
    });

    test('switchSession mengubah activeSessionId', () {
      vm.createNewSession();
      final secondId = vm.activeSessionId;
      final firstId = vm.sessions[1].id;

      vm.switchSession(firstId);
      expect(vm.activeSessionId, firstId);
      expect(vm.activeSessionId, isNot(secondId));
    });

    test('renameSession mengubah title sesi', () {
      final sessionId = vm.activeSessionId!;
      vm.renameSession(sessionId, 'Tentang Sabar');
      expect(vm.sessions.first.title, 'Tentang Sabar');
    });

    test('renameSession dengan string kosong tidak mengubah', () {
      final sessionId = vm.activeSessionId!;
      vm.renameSession(sessionId, '');
      expect(vm.sessions.first.title, 'Obrolan Baru');
    });

    test('deleteSession menghapus sesi dan buat baru jika kosong', () {
      final sessionId = vm.activeSessionId!;
      vm.deleteSession(sessionId);

      // sesi dihapus tapi otomatis buat baru supaya tidak kosong
      expect(vm.sessions.length, 1);
      expect(vm.activeSessionId, isNotNull);
      expect(vm.activeSessionId, isNot(sessionId));
    });

    test('deleteSession pindah ke sesi lain kalau masih ada', () {
      vm.createNewSession();
      expect(vm.sessions.length, 2);

      final activeId = vm.activeSessionId!;
      final otherId = vm.sessions.firstWhere((s) => s.id != activeId).id;

      vm.deleteSession(activeId);
      expect(vm.activeSessionId, otherId);
      expect(vm.sessions.length, 1);
    });

    test('clearAllSessions reset semua dan buat sesi baru', () {
      vm.createNewSession();
      vm.createNewSession();
      expect(vm.sessions.length, 3);

      vm.clearAllSessions();
      expect(vm.sessions.length, 1);
    });
  });

  // ---------- Confirm Delete Session ----------

  group('Confirm Delete Session', () {
    test('requestDeleteSession set pendingDeleteSessionId', () {
      final sessionId = vm.activeSessionId!;
      vm.requestDeleteSession(sessionId);
      expect(vm.pendingDeleteSessionId, sessionId);
    });

    test('confirmDeleteSession hapus sesi', () {
      vm.createNewSession();
      expect(vm.sessions.length, 2);

      final toDelete = vm.sessions.last.id;
      vm.requestDeleteSession(toDelete);
      vm.confirmDeleteSession();

      expect(vm.pendingDeleteSessionId, isNull);
      expect(vm.sessions.any((s) => s.id == toDelete), isFalse);
    });

    test('cancelDeleteSession clear pending tanpa menghapus', () {
      final sessionId = vm.activeSessionId!;
      vm.requestDeleteSession(sessionId);
      vm.cancelDeleteSession();

      expect(vm.pendingDeleteSessionId, isNull);
      expect(vm.sessions.any((s) => s.id == sessionId), isTrue);
    });
  });

  // ---------- currentChat ----------

  group('currentChat', () {
    test('mengembalikan pesan dari sesi aktif', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Hello',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      expect(vm.currentChat.length, 1);
      expect(vm.currentChat.first.text, 'Hello');
    });

    test('kosong saat tidak ada sesi aktif', () {
      vm.activeSessionId = null;
      expect(vm.currentChat, isEmpty);
    });
  });

  // ---------- Edit Message ----------

  group('Edit Message', () {
    test('editUserMessage masukkan teks ke input', () {
      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
          id: 'm1',
          text: 'Apa itu sabar?',
          sender: MessageSender.user,
          timestamp: DateTime.now(),
        ),
        MessageModel(
          id: 'm2',
          text: 'Sabar adalah...',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ),
      ]);

      vm.editUserMessage(0);

      expect(vm.isEditingMessage, isTrue);
      expect(vm.textController.text, 'Apa itu sabar?');
    });

    test('editUserMessage TIDAK menghapus pesan sampai sendMessage', () {
      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
          id: 'm1',
          text: 'Apa itu sabar?',
          sender: MessageSender.user,
          timestamp: DateTime.now(),
        ),
        MessageModel(
          id: 'm2',
          text: 'Sabar adalah...',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ),
      ]);

      vm.editUserMessage(0);

      // pesan masih ada (belum dihapus)
      expect(session.messages.length, 2);
    });

    test('cancelEditMode kembalikan state tanpa mengubah pesan', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Apa itu sabar?',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      vm.editUserMessage(0);
      vm.cancelEditMode();

      expect(vm.isEditingMessage, isFalse);
      expect(vm.textController.text, '');
      // pesan asli tetap utuh
      expect(session.messages.length, 1);
      expect(session.messages[0].text, 'Apa itu sabar?');
    });

    test('editUserMessage menolak AI message', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'AI response',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

      vm.editUserMessage(0);

      expect(vm.isEditingMessage, isFalse);
    });

    test('editUserMessage menolak saat sedang loading', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'User text',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      vm.isLoading = true;
      vm.editUserMessage(0);

      expect(vm.isEditingMessage, isFalse);
    });
  });

  // ---------- Delete Message ----------

  group('Delete Message', () {
    test('hapus user message + AI response setelahnya', () {
      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
            id: 'm1',
            text: 'Q1',
            sender: MessageSender.user,
            timestamp: DateTime.now()),
        MessageModel(
            id: 'm2',
            text: 'A1',
            sender: MessageSender.ai,
            timestamp: DateTime.now()),
        MessageModel(
            id: 'm3',
            text: 'Q2',
            sender: MessageSender.user,
            timestamp: DateTime.now()),
      ]);

      vm.deleteMessage(0);

      expect(session.messages.length, 1);
      expect(session.messages[0].text, 'Q2');
    });

    test('hapus AI message saja', () {
      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
            id: 'm1',
            text: 'Q1',
            sender: MessageSender.user,
            timestamp: DateTime.now()),
        MessageModel(
            id: 'm2',
            text: 'A1',
            sender: MessageSender.ai,
            timestamp: DateTime.now()),
      ]);

      vm.deleteMessage(1); // hapus AI

      expect(session.messages.length, 1);
      expect(session.messages[0].text, 'Q1');
    });

    test('hapus user message terakhir tanpa AI partner', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Q1',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      vm.deleteMessage(0);
      expect(session.messages, isEmpty);
    });

    test('index invalid tidak mengubah apapun', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Q1',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      vm.deleteMessage(-1);
      vm.deleteMessage(99);
      expect(session.messages.length, 1);
    });
  });

  // ---------- Send Message ----------

  group('Send Message', () {
    test('auto-title dari pertanyaan pertama', () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenAnswer((_) async => {
            'answer': 'Jawaban AI',
            'references': [],
            'skor_tertinggi': 0.85,
          });

      vm.textController.text = 'Apa makna sabar dalam Al-Quran?';
      vm.sendMessage();

      // tunggu async completed
      await Future.delayed(const Duration(milliseconds: 200));

      expect(vm.sessions.first.title,
          startsWith('Apa makna sabar dalam Al-'));
    });

    test('sendMessage menambah user message + AI response', () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenAnswer((_) async => {
            'answer': 'Ini jawaban AI',
            'references': [],
            'skor_tertinggi': 0.9,
          });

      vm.textController.text = 'Test pertanyaan';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      final msgs = vm.sessions.first.messages;
      expect(msgs.length, 2);
      expect(msgs[0].sender, MessageSender.user);
      expect(msgs[0].text, 'Test pertanyaan');
      expect(msgs[1].sender, MessageSender.ai);
      expect(msgs[1].text, 'Ini jawaban AI');
    });

    test('sendMessage teks kosong tidak dikirim', () {
      vm.textController.text = '   ';
      vm.sendMessage();
      expect(vm.sessions.first.messages, isEmpty);
    });

    test('NlpException 401 set requiresReLogin', () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenThrow(
              const NlpException('Sesi login berakhir', statusCode: 401));

      vm.textController.text = 'Test pertanyaan';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(vm.requiresReLogin, isTrue);
      expect(vm.lastError, isNotNull);
    });

    test('NlpCancelledException menampilkan "Response dihentikan"', () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenThrow(const NlpCancelledException());

      vm.textController.text = 'Test pertanyaan';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      final lastMsg = vm.sessions.first.messages.last;
      expect(lastMsg.text, 'Response dihentikan.');
      expect(lastMsg.sender, MessageSender.ai);
    });

    test('unexpected error set lastError fallback message', () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenThrow(Exception('unexpected'));

      vm.textController.text = 'Test pertanyaan';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(vm.lastError, contains('tidak terduga'));
    });
  });

  // ---------- Regenerate ----------

  group('Regenerate', () {
    test('regenerateLastResponse menolak kalau pesan terakhir bukan AI', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Q',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));

      // seharusnya tidak crash dan tidak mengubah state
      vm.regenerateLastResponse();
      expect(session.messages.length, 1);
    });

    test('regenerateLastResponse hapus AI terakhir dan kirim ulang',
        () async {
      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenAnswer((_) async => {
            'answer': 'Jawaban baru',
            'references': [],
            'skor_tertinggi': 0.9,
          });

      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
            id: 'm1',
            text: 'Apa itu iman?',
            sender: MessageSender.user,
            timestamp: DateTime.now()),
        MessageModel(
            id: 'm2',
            text: 'Jawaban lama',
            sender: MessageSender.ai,
            timestamp: DateTime.now()),
      ]);

      vm.regenerateLastResponse();
      await Future.delayed(const Duration(milliseconds: 200));

      // jawaban lama dihapus, jawaban baru ditambahkan
      expect(session.messages.length, 2);
      expect(session.messages.last.text, 'Jawaban baru');
    });
  });

  // ---------- Chat History / Memory Buffer ----------

  group('Chat History', () {
    test('sendMessage mengirim riwayat percakapan ke NlpService', () async {
      List<Map<String, String>>? capturedHistory;

      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenAnswer((inv) async {
        capturedHistory =
            inv.namedArguments[#chatHistory] as List<Map<String, String>>?;
        return {
          'answer': 'AI',
          'references': [],
          'skor_tertinggi': 0.9,
        };
      });

      // tambahkan pesan sebelumnya
      final session = vm.sessions.first;
      session.messages.addAll([
        MessageModel(
            id: 'm1',
            text: 'Apa itu sabar?',
            sender: MessageSender.user,
            timestamp: DateTime.now()),
        MessageModel(
            id: 'm2',
            text: 'Sabar adalah...',
            sender: MessageSender.ai,
            timestamp: DateTime.now()),
      ]);

      vm.textController.text = 'Jelaskan lebih lanjut';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(capturedHistory, isNotNull);
      expect(capturedHistory!.length, 2);
      expect(capturedHistory![0]['peran'], 'user');
      expect(capturedHistory![0]['konten'], 'Apa itu sabar?');
      expect(capturedHistory![1]['peran'], 'ai');
      expect(capturedHistory![1]['konten'], 'Sabar adalah...');
    });

    test('pertanyaan pertama tidak mengirim riwayat', () async {
      List<Map<String, String>>? capturedHistory;

      when(() => mockNlp.getAnswerFromVectorDB(
            any(),
            client: any(named: 'client'),
            chatHistory: any(named: 'chatHistory'),
          )).thenAnswer((inv) async {
        capturedHistory =
            inv.namedArguments[#chatHistory] as List<Map<String, String>>?;
        return {
          'answer': 'AI',
          'references': [],
          'skor_tertinggi': 0.9,
        };
      });

      vm.textController.text = 'Apa itu iman?';
      vm.sendMessage();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(capturedHistory, isNull);
    });
  });

  // ---------- Error Handling ----------

  group('Error Handling', () {
    test('clearError reset semua state error', () {
      vm.lastError = 'Some error';
      vm.requiresReLogin = true;

      vm.clearError();

      expect(vm.lastError, isNull);
      expect(vm.requiresReLogin, isFalse);
    });
  });

  // ---------- Edge Cases ----------

  group('Edge Cases', () {
    test('switchSession membatalkan mode edit', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Q',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      vm.editUserMessage(0);
      expect(vm.isEditingMessage, isTrue);

      vm.createNewSession();
      final newId = vm.activeSessionId!;
      vm.switchSession(session.id);
      vm.switchSession(newId);

      expect(vm.isEditingMessage, isFalse);
    });

    test('createNewSession membatalkan mode edit', () {
      final session = vm.sessions.first;
      session.messages.add(MessageModel(
        id: 'm1',
        text: 'Q',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      vm.editUserMessage(0);

      vm.createNewSession();
      expect(vm.isEditingMessage, isFalse);
    });

    test('deleteSession membatalkan mode edit', () {
      vm.createNewSession();
      final first = vm.sessions.last;
      first.messages.add(MessageModel(
        id: 'm1',
        text: 'Q',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      vm.switchSession(first.id);
      vm.editUserMessage(0);

      vm.deleteSession(first.id);
      expect(vm.isEditingMessage, isFalse);
    });
  });
}
