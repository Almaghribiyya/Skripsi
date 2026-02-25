import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/chat_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel(),
      child: MaterialApp(
        title: "Al-Qur'an AI",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF064C3E),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashView(),
          '/login': (context) => const LoginView(),
          '/chat': (context) => const ChatView(),
        },
      ),
    );
  }
}