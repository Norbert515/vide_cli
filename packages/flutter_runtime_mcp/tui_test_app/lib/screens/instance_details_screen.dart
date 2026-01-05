import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'output_screen.dart';
import '../dialogs/act_dialog.dart';
import '../dialogs/manual_tap_dialog.dart';

/// Screen showing detailed information about a Flutter instance
class InstanceDetailsScreen extends StatefulComponent {
  final FlutterRuntimeServer server;
  final FlutterInstance instance;
  final Map<String, FlutterInstance>? localInstances;

  const InstanceDetailsScreen({
    required this.server,
    required this.instance,
    this.localInstances,
    super.key,
  });

  @override
  State<InstanceDetailsScreen> createState() => _InstanceDetailsScreenState();
}

class _InstanceDetailsScreenState extends State<InstanceDetailsScreen> {
  String? _statusMessage;

  @override
  Component build(BuildContext context) {
    final screenComponent = context.component as InstanceDetailsScreen;
    final instance = screenComponent.instance;
    final localInstances = screenComponent.localInstances;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        // Hot reload
        if (event.logicalKey == LogicalKey.keyR && !event.modifiers.shift) {
          _hotReload(instance);
          return true;
        }

        // Hot restart (Shift+R)
        if (event.logicalKey == LogicalKey.keyR && event.modifiers.shift) {
          _hotRestart(instance);
          return true;
        }

        // View output
        if (event.logicalKey == LogicalKey.keyO) {
          Navigator.of(context)
              .push(
                PageRoute(
                  builder: (context) => OutputScreen(
                    server: screenComponent.server,
                    instance: instance,
                  ),
                  settings: const RouteSettings(name: '/output'),
                ),
              )
              .then((_) => setState(() {}));
          return true;
        }

        // Screenshot
        if (event.logicalKey == LogicalKey.keyS) {
          _takeScreenshot(instance);
          return true;
        }

        // Act (AI-powered tap)
        if (event.logicalKey == LogicalKey.keyA) {
          _showActDialog(context, instance, screenComponent.server);
          return true;
        }

        // Manual tap test
        if (event.logicalKey == LogicalKey.keyT) {
          _showManualTapDialog(context, instance);
          return true;
        }

        // Diagnostics
        if (event.logicalKey == LogicalKey.keyD) {
          _showDiagnostics(context, instance);
          return true;
        }

        // Stop instance
        if (event.logicalKey == LogicalKey.keyK) {
          _stopInstance(instance, localInstances).then((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
          return true;
        }

        // Back
        if (event.logicalKey == LogicalKey.keyB ||
            event.logicalKey == LogicalKey.escape) {
          Navigator.of(context).pop();
          return true;
        }

        return false;
      },
      child: Container(
        decoration: const BoxDecoration(color: Color.fromRGB(15, 15, 35)),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildDetails(instance)),
            if (_statusMessage != null) _buildStatusBar(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Component _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color.fromRGB(30, 60, 120),
        border: BoxBorder.all(color: Colors.cyan, style: BoxBorderStyle.double),
      ),
      child: const Text(
        'Instance Details',
        style: TextStyle(
          color: Colors.brightWhite,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Component _buildDetails(FlutterInstance instance) {
    final statusColor = instance.isRunning ? Colors.green : Colors.red;
    final statusText = instance.isRunning ? '🟢 Running' : '🔴 Stopped';

    return Container(
      padding: const EdgeInsets.all(2),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status:', statusText, valueColor: statusColor),
            _buildDetailRow('ID:', instance.id, valueColor: Colors.cyan),
            _buildDetailRow(
              'Started:',
              instance.startedAt.toString(),
              valueColor: Colors.yellow,
            ),
            _buildDetailRow(
              'Uptime:',
              _formatDuration(DateTime.now().difference(instance.startedAt)),
              valueColor: Colors.yellow,
            ),
            const SizedBox(height: 1),
            const Divider(color: Colors.blue),
            const SizedBox(height: 1),
            _buildDetailRow(
              'Working Directory:',
              '',
              valueColor: Colors.magenta,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                instance.workingDirectory,
                style: const TextStyle(color: Colors.magenta),
              ),
            ),
            const SizedBox(height: 1),
            _buildDetailRow('Command:', '', valueColor: Colors.green),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                instance.command.join(' '),
                style: const TextStyle(color: Colors.green),
              ),
            ),
            const SizedBox(height: 1),
            const Divider(color: Colors.blue),
            const SizedBox(height: 1),
            _buildDetailRow(
              'Device:',
              instance.deviceId ?? 'parsing...',
              valueColor: Colors.brightCyan,
            ),
            _buildDetailRow(
              'VM Service:',
              instance.vmServiceUri ?? 'not available',
              valueColor: instance.vmServiceUri != null
                  ? Colors.brightGreen
                  : Colors.gray,
            ),
            const SizedBox(height: 1),
            const Divider(color: Colors.blue),
            const SizedBox(height: 1),
            _buildDetailRow(
              'Output Lines:',
              '${instance.bufferedOutput.length}',
              valueColor: Colors.yellow,
            ),
            _buildDetailRow(
              'Error Lines:',
              '${instance.bufferedErrors.length}',
              valueColor: instance.bufferedErrors.isEmpty
                  ? Colors.gray
                  : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Component _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.gray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(' '),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white)),
      ],
    );
  }

  Component _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: const BoxDecoration(
        color: Color.fromRGB(40, 60, 80),
        border: BoxBorder(top: BorderSide(color: Colors.yellow)),
      ),
      child: Text(
        _statusMessage!,
        style: const TextStyle(color: Colors.yellow),
      ),
    );
  }

  Component _buildFooter() {
    return const Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Color.fromRGB(20, 20, 40),
        border: BoxBorder(top: BorderSide(color: Colors.blue)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('[R] Reload', style: TextStyle(color: Colors.green)),
              Text(' • '),
              Text('[Shift+R] Restart', style: TextStyle(color: Colors.yellow)),
              Text(' • '),
              Text('[O] Output', style: TextStyle(color: Colors.cyan)),
              Text(' • '),
              Text('[S] Screenshot', style: TextStyle(color: Colors.magenta)),
              Text(' • '),
              Text('[A] Act', style: TextStyle(color: Colors.brightMagenta)),
              Text(' • '),
              Text(
                '[T] Manual Tap',
                style: TextStyle(color: Colors.brightYellow),
              ),
              Text(' • '),
              Text('[K] Stop', style: TextStyle(color: Colors.red)),
            ],
          ),
          Text('[B/Esc] Back', style: TextStyle(color: Colors.gray)),
        ],
      ),
    );
  }

  Future<void> _hotReload(FlutterInstance instance) async {
    setState(() {
      _statusMessage = '⏳ Triggering hot reload...';
    });

    try {
      await instance.hotReload();
      setState(() {
        _statusMessage = '✓ Hot reload triggered successfully';
      });
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Hot reload failed: $e';
      });
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  Future<void> _hotRestart(FlutterInstance instance) async {
    setState(() {
      _statusMessage = '⏳ Triggering hot restart...';
    });

    try {
      await instance.hotRestart();
      setState(() {
        _statusMessage = '✓ Hot restart triggered successfully';
      });
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Hot restart failed: $e';
      });
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  Future<void> _takeScreenshot(FlutterInstance instance) async {
    setState(() {
      _statusMessage = '⏳ Taking screenshot...';
    });

    try {
      final screenshot = await instance.screenshot();

      if (screenshot != null) {
        final filename =
            'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filename);
        await file.writeAsBytes(screenshot);

        setState(() {
          _statusMessage =
              '✓ Screenshot saved: $filename (${screenshot.length} bytes)';
        });
      } else {
        setState(() {
          _statusMessage =
              '✗ Screenshot returned null - VM Service may not be available';
        });
      }

      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Screenshot failed: $e';
      });
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  Future<void> _stopInstance(
    FlutterInstance instance,
    Map<String, FlutterInstance>? localInstances,
  ) async {
    setState(() {
      _statusMessage = '⏳ Stopping instance...';
    });

    try {
      await instance.stop();
      localInstances?.remove(instance.id);
      setState(() {
        _statusMessage = '✓ Instance stopped successfully';
      });
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Stop failed: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _showActDialog(
    BuildContext context,
    FlutterInstance instance,
    FlutterRuntimeServer server,
  ) async {
    final result = await Navigator.of(
      context,
    ).showDialog<Map<String, dynamic>>(builder: (context) => const ActDialog());

    if (result != null && mounted) {
      final action = result['action'] as String;
      final description = result['description'] as String;

      await _performAct(instance, action, description, server);
    }
  }

  Future<void> _performAct(
    FlutterInstance instance,
    String action,
    String description,
    FlutterRuntimeServer server,
  ) async {
    setState(() {
      _statusMessage =
          '⏳ Analyzing UI and performing $action on "$description"...';
    });

    try {
      // Call the server's flutterAct tool by passing the instance directly
      final result = await server.callFlutterAct(
        instance: instance,
        action: action,
        description: description,
      );

      setState(() {
        _statusMessage = '✓ $result';
      });
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ $e';
      });
      await Future.delayed(const Duration(seconds: 5));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  void _showManualTapDialog(
    BuildContext context,
    FlutterInstance instance,
  ) async {
    final result = await Navigator.of(context).showDialog<Map<String, dynamic>>(
      builder: (context) => const ManualTapDialog(),
    );

    if (result != null && mounted) {
      final x = result['x'] as double;
      final y = result['y'] as double;

      await _performManualTap(instance, x, y);
    }
  }

  Future<void> _performManualTap(
    FlutterInstance instance,
    double x,
    double y,
  ) async {
    setState(() {
      _statusMessage = '⏳ Tapping at ($x, $y)...';
    });

    try {
      await instance.tap(x, y);

      setState(() {
        _statusMessage = '✓ Successfully tapped at ($x, $y)';
      });
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _statusMessage = null;
      });
    } catch (e, stackTrace) {
      setState(() {
        _statusMessage = '✗ Tap failed: $e\n$stackTrace';
      });
      await Future.delayed(const Duration(seconds: 4));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  void _showDiagnostics(BuildContext context, FlutterInstance instance) async {
    setState(() {
      _statusMessage = '⏳ Running diagnostics...';
    });

    try {
      // Access the evaluator
      final evaluator = instance.evaluator;
      if (evaluator == null) {
        setState(() {
          _statusMessage =
              '✗ No evaluator available - VM Service may not be connected';
        });
        await Future.delayed(const Duration(seconds: 3));
        setState(() {
          _statusMessage = null;
        });
        return;
      }

      // Run class availability test
      setState(() {
        _statusMessage = '⏳ Testing class availability...';
      });

      final classTests = await evaluator.diagnoseAvailableClasses();

      // Format results
      final available = <String>[];
      final unavailable = <String>[];

      classTests.forEach((className, isAvailable) {
        if (isAvailable) {
          available.add(className);
        } else {
          unavailable.add(className);
        }
      });

      setState(() {
        _statusMessage =
            'Available: ${available.length} | Unavailable: ${unavailable.length}\n'
            'Available: ${available.take(5).join(", ")}...\n'
            'Unavailable: ${unavailable.take(5).join(", ")}...';
      });

      await Future.delayed(const Duration(seconds: 8));

      // Run overlay creation test
      setState(() {
        _statusMessage = '⏳ Testing overlay creation (step-by-step)...';
      });

      final overlayTests = await evaluator.testOverlayCreation(100, 100);

      // Show overlay test results
      final resultsText = overlayTests.entries
          .map((e) {
            final status = e.value.startsWith('SUCCESS') ? '✓' : '✗';
            return '$status ${e.key}';
          })
          .join('\n');

      setState(() {
        _statusMessage = 'Overlay tests:\n$resultsText';
      });

      await Future.delayed(const Duration(seconds: 12));

      // Run alternative approaches test
      setState(() {
        _statusMessage = '⏳ Testing alternative approaches...';
      });

      final altTests = await evaluator.testAlternativeApproaches(100, 100);

      // Show alternative test results
      final altResultsText = altTests.entries
          .map((e) {
            final status = e.value.startsWith('SUCCESS') ? '✓' : '✗';
            return '$status ${e.key}';
          })
          .join('\n');

      setState(() {
        _statusMessage = 'Alternative approaches:\n$altResultsText';
      });

      await Future.delayed(const Duration(seconds: 10));

      setState(() {
        _statusMessage = '✓ Diagnostics complete!';
      });

      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '✗ Diagnostics failed: $e';
      });
      await Future.delayed(const Duration(seconds: 5));
      setState(() {
        _statusMessage = null;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
