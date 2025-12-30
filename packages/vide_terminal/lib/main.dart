import 'package:flutter/material.dart';

import 'terminal_page.dart';

void main() {
  runApp(const VideTerminalApp());
}

class VideTerminalApp extends StatelessWidget {
  const VideTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vide Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF569CD6),
          secondary: Color(0xFF4EC9B0),
          surface: Color(0xFF252526),
        ),
      ),
      home: const TerminalPage(),
    );
  }
}
