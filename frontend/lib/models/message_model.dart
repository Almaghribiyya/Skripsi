// file: lib/models/message_model.dart

enum MessageSender { user, ai }

class VerseReference {
  final String surahName;
  final String ayatNumber;
  final String arabicText;
  final String translation;
  final String transliteration;

  VerseReference({
    required this.surahName,
    required this.ayatNumber,
    required this.arabicText,
    required this.translation,
    this.transliteration = '',
  });

  factory VerseReference.fromJson(Map<String, dynamic> json) {
    return VerseReference(
      surahName: json['surah'] ?? '',
      ayatNumber: (json['ayat'] ?? '').toString(),
      arabicText: json['teks_arab'] ?? '',
      translation: json['terjemahan'] ?? '',
      transliteration: json['transliterasi'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'surah': surahName,
        'ayat': ayatNumber,
        'teks_arab': arabicText,
        'terjemahan': translation,
        'transliterasi': transliteration,
      };
}

class MessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<VerseReference>? verseReferences;

  MessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.verseReferences,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      sender: json['sender'] == 'ai' ? MessageSender.ai : MessageSender.user,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : DateTime.now(),
      verseReferences: json['verseReferences'] != null
          ? (json['verseReferences'] as List)
              .map((v) => VerseReference.fromJson(v))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'sender': sender == MessageSender.ai ? 'ai' : 'user',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'verseReferences': verseReferences?.map((v) => v.toJson()).toList(),
      };
}

class ChatSession {
  final String id;
  String title;
  List<MessageModel> messages;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    List<MessageModel>? messages,
    required this.createdAt,
  }) : messages = messages ?? [];

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Obrolan Baru',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => MessageModel.fromJson(m))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}