import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../services/nlp_service.dart';
import '../services/firestore_service.dart';

// viewmodel utama untuk fitur chat.
// mengelola multi-sesi, pengiriman pesan, loading state,
// error handling, dan penyimpanan ke firestore.
class ChatViewModel extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final NlpService _nlpService;
  final FirestoreService _firestoreService;
  
  List<ChatSession> sessions = [];
  String? activeSessionId;
  bool isLoading = false;

  // pesan error terakhir, ditampilkan sebagai snackbar oleh ui lalu di-clear
  String? lastError;

  // flag kalau error terakhir butuh login ulang
  bool requiresReLogin = false;

  // flag mode edit, true saat pengguna mengedit prompt lama
  bool isEditingMessage = false;

  // http client aktif untuk membatalkan request yang sedang berjalan
  http.Client? _activeClient;

  String? _currentUid;

  List<MessageModel> get currentChat {
    if (activeSessionId == null) return [];
    final idx = sessions.indexWhere((s) => s.id == activeSessionId);
    if (idx == -1) return [];
    return sessions[idx].messages;
  }

  ChatViewModel({NlpService? nlpService, FirestoreService? firestoreService})
      : _nlpService = nlpService ?? NlpService(),
        _firestoreService = firestoreService ?? FirestoreService() {
    createNewSession();
  }

  // reset error state setelah ditampilkan oleh ui
  void clearError() {
    lastError = null;
    requiresReLogin = false;
  }

  // dipanggil setelah login berhasil, muat sesi obrolan dari firestore
  Future<void> loadUserSessions(String uid) async {
    _currentUid = uid;
    try {
      final loaded = await _firestoreService.loadChatSessions(uid);
      if (loaded.isNotEmpty) {
        sessions = loaded;
        activeSessionId = sessions.first.id;
      } else {
        if (sessions.isNotEmpty) {
          await _firestoreService.saveChatSession(uid, sessions.first);
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat sesi obrolan: $e');
    }
    notifyListeners();
  }

  void createNewSession() {
    if (isEditingMessage) cancelEditMode();
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Obrolan Baru",
      messages: [],
      createdAt: DateTime.now(),
    );
    sessions.insert(0, newSession);
    activeSessionId = newSession.id;
    notifyListeners();
    _saveSessionToFirestore(newSession);
  }

  void switchSession(String sessionId) {
    if (isEditingMessage) cancelEditMode();
    activeSessionId = sessionId;
    notifyListeners();
    _scrollToBottom();
  }

  void renameSession(String sessionId, String newTitle) {
    final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1 && newTitle.isNotEmpty) {
      sessions[sessionIndex].title = newTitle;
      notifyListeners();
      _saveSessionToFirestore(sessions[sessionIndex]);
    }
  }

  void deleteSession(String sessionId) {
    if (isEditingMessage) cancelEditMode();
    sessions.removeWhere((s) => s.id == sessionId);
    _deleteSessionFromFirestore(sessionId);
    if (sessions.isEmpty) {
      createNewSession();
    } else if (activeSessionId == sessionId) {
      activeSessionId = sessions.first.id;
    }
    notifyListeners();
  }

  void clearAllSessions() {
    sessions.clear();
    activeSessionId = null;
    _currentUid = null;
    textController.clear();
    isEditingMessage = false;
    createNewSession();
  }

  // jumlah pesan riwayat yang dikirim ke backend (5 giliran = 10 pesan)
  static const int _maxHistoryMessages = 10;

  // index pesan yang sedang diedit, untuk auto-send setelah edit
  int? _editingAtIndex;

  // edit prompt pengguna di posisi tertentu (seperti Gemini/ChatGPT).
  // hapus pesan dari posisi itu sampai akhir, masukkan teks ke input.
  // saat user menekan kirim, pesan langsung terkirim dari posisi itu.
  void editUserMessage(int messageIndex) {
    if (activeSessionId == null || isLoading) return;
    final sessionIndex = sessions.indexWhere((s) => s.id == activeSessionId);
    if (sessionIndex == -1) return;

    final messages = sessions[sessionIndex].messages;
    if (messageIndex < 0 || messageIndex >= messages.length) return;
    if (messages[messageIndex].sender != MessageSender.user) return;

    final editText = messages[messageIndex].text;

    // simpan index pesan yang diedit — pesan BELUM dihapus sampai user
    // benar-benar menekan kirim (seperti ChatGPT/Gemini mobile).
    // jika user membatalkan edit, pesan asli tetap utuh.
    _editingAtIndex = messageIndex;

    // masukkan teks ke input field
    textController.text = editText;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: editText.length),
    );

    isEditingMessage = true;
    notifyListeners();
  }

  // regenerate: hapus jawaban AI terakhir lalu minta ulang.
  // mirip tombol "Regenerate" di ChatGPT/Gemini.
  void regenerateLastResponse() {
    if (activeSessionId == null || isLoading) return;
    final sessionIndex = sessions.indexWhere((s) => s.id == activeSessionId);
    if (sessionIndex == -1) return;

    final messages = sessions[sessionIndex].messages;
    if (messages.isEmpty) return;

    // cari pesan AI terakhir
    if (messages.last.sender != MessageSender.ai) return;

    // cari pesan user sebelum AI terakhir
    String? lastUserText;
    for (int i = messages.length - 2; i >= 0; i--) {
      if (messages[i].sender == MessageSender.user) {
        lastUserText = messages[i].text;
        break;
      }
    }
    if (lastUserText == null) return;

    // hapus jawaban AI terakhir
    messages.removeLast();
    notifyListeners();

    // kirim ulang pertanyaan yang sama
    textController.text = lastUserText;
    sendMessage(isRegenerate: true);
  }

  // hapus satu pesan tertentu beserta response AI-nya (jika ada).
  // jika user message dihapus, ai response langsung setelahnya juga dihapus.
  void deleteMessage(int messageIndex) {
    if (activeSessionId == null || isLoading) return;
    final sessionIndex = sessions.indexWhere((s) => s.id == activeSessionId);
    if (sessionIndex == -1) return;

    final messages = sessions[sessionIndex].messages;
    if (messageIndex < 0 || messageIndex >= messages.length) return;

    final msg = messages[messageIndex];
    if (msg.sender == MessageSender.user) {
      // hapus user message + ai response setelahnya (jika ada)
      int endIdx = messageIndex + 1;
      if (endIdx < messages.length &&
          messages[endIdx].sender == MessageSender.ai) {
        endIdx++;
      }
      messages.removeRange(messageIndex, endIdx);
    } else {
      // hapus hanya pesan AI
      messages.removeAt(messageIndex);
    }

    notifyListeners();
    _saveSessionToFirestore(sessions[sessionIndex]);
  }

  // flag untuk konfirmasi hapus sesi, UI harus memanggil confirmDeleteSession
  String? pendingDeleteSessionId;

  // request hapus sesi — set pending ID lalu UI tampilkan dialog
  void requestDeleteSession(String sessionId) {
    pendingDeleteSessionId = sessionId;
    notifyListeners();
  }

  // konfirmasi hapus sesi setelah dialog
  void confirmDeleteSession() {
    if (pendingDeleteSessionId != null) {
      deleteSession(pendingDeleteSessionId!);
      pendingDeleteSessionId = null;
    }
  }

  // batalkan hapus sesi
  void cancelDeleteSession() {
    pendingDeleteSessionId = null;
    notifyListeners();
  }

  // batalkan mode edit
  void cancelEditMode() {
    isEditingMessage = false;
    _editingAtIndex = null;
    textController.clear();
    notifyListeners();
  }

  // hentikan response yang sedang di-generate.
  // tutup http client aktif sehingga request dibatalkan.
  void stopResponse() {
    if (!isLoading || _activeClient == null) return;
    _activeClient!.close();
    _activeClient = null;
    // state akan di-update oleh catch block di sendMessage
  }

  void sendMessage({bool isRegenerate = false}) async {
    final text = textController.text.trim();
    if (text.isEmpty || activeSessionId == null) return;

    final targetSessionId = activeSessionId!;
    int sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
    if (sessionIndex == -1) return;

    // jika sedang dalam mode edit, hapus pesan dari titik edit ke akhir.
    // pesan asli baru dibuang di sini (bukan saat editUserMessage dipanggil)
    // supaya cancel edit tidak menghancurkan pesan.
    if (_editingAtIndex != null) {
      final editIdx = _editingAtIndex!;
      final msgs = sessions[sessionIndex].messages;
      if (editIdx < msgs.length) {
        msgs.removeRange(editIdx, msgs.length);
      }
    }

    // auto-title dari pesan pertama
    if (sessions[sessionIndex].messages.isEmpty) {
      sessions[sessionIndex].title =
          text.length > 25 ? "${text.substring(0, 25)}..." : text;
    }

    // saat regenerate, pesan user sudah ada di list, tidak perlu tambah lagi
    if (!isRegenerate) {
      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: text,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
    }
    
    textController.clear();
    isLoading = true;
    isEditingMessage = false;
    _editingAtIndex = null;
    lastError = null;
    requiresReLogin = false;
    notifyListeners();
    _scrollToBottom();

    // buat client baru untuk request ini supaya bisa di-cancel
    _activeClient = http.Client();

    // kumpulkan riwayat percakapan sebelumnya untuk memory buffer.
    // ambil maksimal _maxHistoryMessages pesan terakhir SEBELUM pesan
    // yang baru ditambahkan (pesan terakhir di list adalah yang baru).
    List<Map<String, String>>? chatHistory;
    final allMessages = sessions[sessionIndex].messages;
    if (allMessages.length > 1) {
      // ambil pesan sebelum pesan user yang baru saja ditambahkan
      final historyMessages = allMessages.sublist(
        (allMessages.length - 1 - _maxHistoryMessages).clamp(0, allMessages.length - 1),
        allMessages.length - 1,
      );
      if (historyMessages.isNotEmpty) {
        chatHistory = historyMessages.map((m) => {
          'peran': m.sender == MessageSender.user ? 'user' : 'ai',
          'konten': m.text,
        }).toList();
      }
    }

    try {
      final response = await _nlpService.getAnswerFromVectorDB(
        text,
        client: _activeClient,
        chatHistory: chatHistory,
      );

      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      List<VerseReference> refs = [];
      if (response['references'] != null) {
        refs = (response['references'] as List)
            .map((data) => VerseReference.fromJson(data))
            .toList();
      }

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: response['answer'],
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        verseReferences: refs,
      ));

    } on NlpCancelledException {
      // user menekan tombol stop, tidak perlu tampilkan error
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: 'Response dihentikan.',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } on NlpException catch (e) {
      // error dari nlp service dengan status code spesifik
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      // kalau 401, tandai untuk login ulang
      if (e.statusCode == 401) {
        requiresReLogin = true;
        lastError = e.message;
      } else {
        lastError = e.message;
      }

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: e.message,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      // fallback untuk error tak terduga
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      const fallbackMsg = "Maaf, terjadi kesalahan yang tidak terduga. "
          "Silakan coba lagi.";
      lastError = fallbackMsg;

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: fallbackMsg,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } finally {
      _activeClient = null;
      isLoading = false;
      notifyListeners();
      _scrollToBottom();

      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex != -1) {
        _saveSessionToFirestore(sessions[sessionIndex]);
      }
    }
  }

  // penyimpanan firestore

  // simpan satu sesi ke firestore (non-blocking)
  void _saveSessionToFirestore(ChatSession session) {
    if (_currentUid == null) return;
    _firestoreService.saveChatSession(_currentUid!, session).catchError((e) {
      debugPrint('Gagal menyimpan sesi ke Firestore: $e');
    });
  }

  // hapus satu sesi dari firestore (non-blocking)
  void _deleteSessionFromFirestore(String sessionId) {
    if (_currentUid == null) return;
    _firestoreService.deleteChatSession(_currentUid!, sessionId).catchError((e) {
      debugPrint('Gagal menghapus sesi dari Firestore: $e');
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}