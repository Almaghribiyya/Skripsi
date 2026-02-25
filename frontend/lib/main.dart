import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Jangan lupa import ini
import 'viewmodels/chat_viewmodel.dart';
import 'views/chat_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
      ],
      child: const PustakaQnaApp(),
    ),
  );
}

class PustakaQnaApp extends StatelessWidget {
  const PustakaQnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al-Quran Digital QnA',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF102216),
        primaryColor: const Color(0xFF0FB345),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0FB345),
          surface: Color(0xFF172B1E),
        ),
      ),
      home: const ChatView(),
    );
  }
}