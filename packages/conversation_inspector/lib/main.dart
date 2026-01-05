import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const ConversationInspectorApp());
}

class ConversationInspectorApp extends StatelessWidget {
  const ConversationInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversation Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardTheme: const CardThemeData(
          color: Color(0xFF252526),
          elevation: 0,
        ),
        dividerColor: Colors.grey.shade800,
      ),
      home: const HomePage(),
    );
  }
}
