import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'screens/home_screen.dart';

/// Main application component
class FlutterRuntimeApp extends StatelessComponent {
  final FlutterRuntimeServer server;

  const FlutterRuntimeApp({required this.server, super.key});

  @override
  Component build(BuildContext context) {
    return Navigator(
      home: HomeScreen(server: server),
      popBehavior: const PopBehavior(escapeEnabled: true, customPopKey: 'q'),
    );
  }
}
