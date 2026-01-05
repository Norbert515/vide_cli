import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/form_screen.dart';
import 'screens/paywall_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runtime AI Dev Tools Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/form': (context) => const FormScreen(),
        '/paywall': (context) => const PaywallScreen(),
      },
    );
  }
}
