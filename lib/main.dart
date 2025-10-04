import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Streamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Dark theme colors based on Spotify/Material dark theme principles
        scaffoldBackgroundColor: const Color(0xFF121212), // Very dark gray
        primaryColor: const Color(0xFFBB86FC), // Purple accent
        brightness: Brightness.dark,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.white70),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}