import 'package:flutter/material.dart';
import 'package:my_map_app/screens/map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1687C9)),
        scaffoldBackgroundColor: const Color(0xFFEAF5FB),
      ),
      home: const MapPage(),
    );
  }
}
