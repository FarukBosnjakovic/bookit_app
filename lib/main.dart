import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:bookit/firebase_options.dart';
import 'package:bookit/providers/theme_provider.dart';
import 'package:bookit/screens/splash_screen_page.dart';

void main() async {
  // Required before any async work in main
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const BookitApp(),
    ),
  );
}

class BookitApp extends StatelessWidget {
  const BookitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Bookit',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F5E4),
        colorScheme: ColorScheme.light(
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF1A1F14),
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF2A3024),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}