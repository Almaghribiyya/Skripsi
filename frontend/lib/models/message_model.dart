// file: lib/models/message_model.dart

enum MessageSender { user, ai }

class VerseReference {
  final String surahName;
  final String ayatNumber;
  final String arabicText;
  final String translation;

  VerseReference({
    required this.surahName,
    required this.ayatNumber,
    required this.arabicText,
    required this.translation,
  });

  // Contoh fungsi untuk parsing dari JSON RAG backend Anda
  factory VerseReference.fromJson(Map<String, dynamic> json) {
    return VerseReference(
      surahName: json['surah_name'] ?? '',
      ayatNumber: json['ayat_number'] ?? '',
      arabicText: json['arabic_text'] ?? '',
      translation: json['translation'] ?? '',
    );
  }
}

class MessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<VerseReference>? verseReferences; // Hanya terisi jika sender == ai

  MessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.verseReferences,
  });
}