import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:my_map_app/config/map_config.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/screens/map_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
  try {
    await SocialConfig.initialize();
  } catch (error) {
    debugPrint('Could not initialize social features: $error');
  }
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
