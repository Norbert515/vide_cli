import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import '../components/instance_list_item.dart';
import '../dialogs/start_instance_dialog.dart';
import 'instance_details_screen.dart';

/// Home screen showing list of running Flutter instances
class HomeScreen extends StatefulComponent {
  final FlutterRuntimeServer server;

  const HomeScreen({required this.server, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, FlutterInstance> _localInstances = {};
  Timer? _refreshTimer;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Refresh list every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<FlutterInstance> get _allInstances {
    final homeScreen = context.component as HomeScreen;
    return [...homeScreen.server.getAllInstances(), ..._localInstances.values];
  }

  @override
  Component build(BuildContext context) {
    final instances = _allInstances;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        // Navigation
        if (event.logicalKey == LogicalKey.arrowDown && instances.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % instances.length;
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp && instances.isNotEmpty) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + instances.length) % instances.length;
          });
          return true;
        }

        // Start new instance
        if (event.logicalKey == LogicalKey.keyS) {
          _showStartDialog(context).then((_) {
            // Dialog closed, refresh UI
            setState(() {});
          });
          return true;
        }

        // View instance details
        if (event.logicalKey == LogicalKey.enter && instances.isNotEmpty) {
          final instance = instances[_selectedIndex];
          final homeScreen = context.component as HomeScreen;
          Navigator.of(context)
              .push(
                PageRoute(
                  builder: (context) => InstanceDetailsScreen(
                    server: homeScreen.server,
                    instance: instance,
                    localInstances: _localInstances,
                  ),
                  settings: const RouteSettings(name: '/details'),
                ),
              )
              .then((_) => setState(() {})); // Refresh on return
          return true;
        }

        // Refresh list
        if (event.logicalKey == LogicalKey.keyR) {
          setState(() {});
          return true;
        }

        // Quit
        if (event.logicalKey == LogicalKey.keyQ) {
          // Stop all instances before quitting
          _stopAllAndQuit();
          return true;
        }

        return false;
      },
      child: Container(
        decoration: const BoxDecoration(color: Color.fromRGB(15, 15, 35)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),

            // Instance list
            Expanded(child: _buildInstanceList(instances)),

            // Footer with controls
            _buildFooter(instances.length),
          ],
        ),
      ),
    );
  }

  Component _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color.fromRGB(30, 60, 120),
        border: BoxBorder.all(color: Colors.cyan, style: BoxBorderStyle.double),
      ),
      child: const Column(
        children: [
          Text(
            '╔════════════════════════════════════════════════════════════════╗',
            style: TextStyle(color: Colors.cyan),
          ),
          Text(
            '║        Flutter Runtime MCP - TUI Test Application             ║',
            style: TextStyle(
              color: Colors.brightWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '╚════════════════════════════════════════════════════════════════╝',
            style: TextStyle(color: Colors.cyan),
          ),
        ],
      ),
    );
  }

  Component _buildInstanceList(List<FlutterInstance> instances) {
    if (instances.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No running instances',
              style: TextStyle(color: Colors.gray, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 2),
            Text(
              'Press [S] to start a new Flutter instance',
              style: TextStyle(color: Colors.brightBlack),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: const BoxDecoration(
              color: Color.fromRGB(25, 25, 45),
              border: BoxBorder(bottom: BorderSide(color: Colors.blue)),
            ),
            child: Text(
              'Running Instances (${instances.length})',
              style: const TextStyle(
                color: Colors.brightCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: instances.length,
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final instance = instances[index];
                final isSelected = index == _selectedIndex;

                return InstanceListItem(
                  instance: instance,
                  isSelected: isSelected,
                  index: index + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Component _buildFooter(int instanceCount) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(
        color: Color.fromRGB(20, 20, 40),
        border: BoxBorder(top: BorderSide(color: Colors.blue)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('[S] Start', style: TextStyle(color: Colors.green)),
              const Text(' • '),
              const Text('[R] Refresh', style: TextStyle(color: Colors.yellow)),
              if (instanceCount > 0) ...[
                const Text(' • '),
                const Text(
                  '[↑↓] Navigate',
                  style: TextStyle(color: Colors.cyan),
                ),
                const Text(' • '),
                const Text(
                  '[Enter] Details',
                  style: TextStyle(color: Colors.magenta),
                ),
              ],
            ],
          ),
          const Text('[Q] Quit', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Future<void> _showStartDialog(BuildContext context) async {
    final result = await Navigator.of(context).showDialog<Map<String, String>>(
      builder: (context) => const StartInstanceDialog(),
      width: 70,
      height: 13,
      decoration: BoxDecoration(
        color: const Color.fromRGB(20, 20, 40),
        border: BoxBorder.all(
          color: Colors.green,
          style: BoxBorderStyle.double,
        ),
      ),
    );

    if (result != null && mounted) {
      final command = result['command']!;
      final workingDir = result['workingDir']!;
      await _startInstance(command, workingDir);
    }
  }

  Future<void> _startInstance(String command, String workingDir) async {
    try {
      final commandParts = _parseCommand(command);

      if (commandParts.isEmpty) {
        // Empty command
        return;
      }

      if (commandParts.first != 'flutter' && commandParts.first != 'fvm') {
        // Not a flutter/fvm command - but still try to start it
        // This allows for custom wrappers
      }

      final instanceId = 'tui-${DateTime.now().millisecondsSinceEpoch}';

      final process = await Process.start(
        commandParts.first,
        commandParts.sublist(1),
        workingDirectory: workingDir,
        mode: ProcessStartMode.normal,
      );

      final instance = FlutterInstance(
        id: instanceId,
        process: process,
        workingDirectory: workingDir,
        command: commandParts,
        startedAt: DateTime.now(),
      );

      _localInstances[instanceId] = instance;

      // Auto-cleanup
      instance.process.exitCode.then((_) {
        _localInstances.remove(instanceId);
        if (mounted) setState(() {});
      });

      setState(() {});
    } catch (e) {
      // Process start failed - instance won't be added to list
      // The error will be visible in the UI (no new instance appears)
    }
  }

  Future<void> _stopAllAndQuit() async {
    for (final instance in _allInstances) {
      try {
        await instance.stop();
      } catch (e) {
        // Ignore errors during shutdown
      }
    }
    shutdownApp();
  }

  List<String> _parseCommand(String command) {
    final parts = <String>[];
    var current = StringBuffer();
    var inQuote = false;
    var quoteChar = '';

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuote) {
        inQuote = false;
        quoteChar = '';
      } else if (char == ' ' && !inQuote) {
        if (current.isNotEmpty) {
          parts.add(current.toString());
          current = StringBuffer();
        }
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      parts.add(current.toString());
    }

    return parts;
  }
}
