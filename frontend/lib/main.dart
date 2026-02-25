import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Sesuaikan path import ini jika nama folder/file Anda berbeda
import 'viewmodels/chat_viewmodel.dart';
import 'views/chat_view.dart';
// import 'firebase_options.dart'; // Nanti ini akan di-uncomment setelah setup flutterfire

import 'firebase_options.dart'; // Buka komentar/tambahkan baris ini
import 'viewmodels/chat_viewmodel.dart';
import 'views/chat_view.dart';

void main() async {
  // Wajib untuk inisialisasi Firebase di Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase
  // Catatan: Jika Anda sudah menjalankan 'flutterfire configure', 
  // gunakan: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp();

  runApp(const MyApp());
}

// Kelas MyApp yang sebelumnya hilang
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
      ],
      child: MaterialApp(
        title: 'Skripsi AI Chat',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF102216), // Sesuai tema warna aplikasi Anda
          primaryColor: const Color(0xFF0FB345),
        ),
        debugShowCheckedModeBanner: false,
        // Untuk sementara langsung ke ChatView. Nanti kita ubah ke LoginView.
        home: const ChatView(), 
      ),
    );
  }
}