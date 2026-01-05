import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'default_renderer.dart';

/// Renderer for Flutter runtime start tool invocations.
/// Streams Flutter process output until the app starts or fails.
class FlutterOutputRenderer extends StatefulComponent {
  final ToolInvocation invocation;
  final AgentId agentId;
  final String workingDirectory;
  final String executionId;

  const FlutterOutputRenderer({
    required this.invocation,
    required this.agentId,
    required this.workingDirectory,
    required this.executionId,
    super.key,
  });

  @override
  State<FlutterOutputRenderer> createState() => _FlutterOutputRendererState();
}

class _FlutterOutputRendererState extends State<FlutterOutputRenderer> {
  final List<String> _outputLines = [];
  bool _hasStartedOrFailed = false;
  bool _hasStartedListening = false;
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    // Can't access context.read in initState - will set up in build
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }

  void _startListening(BuildContext context) {
    if (_hasStartedListening) return;
    _hasStartedListening = true;

    // Get instance ID from parameters (Claude should pass toolUseId as instanceId)
    // Fall back to toolUseId directly if not in parameters
    final instanceId =
        component.invocation.parameters['instanceId'] as String? ??
        component.invocation.toolCall.toolUseId;

    if (instanceId == null) {
      setState(() {
        _outputLines.add('Error: No instance ID available');
        _hasStartedOrFailed = true;
      });
      return;
    }

    final manager = context.read(claudeManagerProvider);
    final client = manager[component.agentId];
    final flutterServer = client?.getMcpServer<FlutterRuntimeServer>(
      'flutter-runtime',
    );

    if (flutterServer == null) {
      setState(() {
        _outputLines.add('Error: Flutter runtime server not found');
        _hasStartedOrFailed = true;
      });
      return;
    }

    var instance = flutterServer.getInstance(instanceId);

    if (instance == null) {
      // Instance not created yet - retry after a short delay
      _hasStartedListening = false;
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          _startListening(context);
        }
      });
      return;
    }

    // Promote to non-nullable for closure capture
    final nonNullInstance = instance;

    // Listen to stdout stream
    _outputSubscription = nonNullInstance.output.listen(
      (line) {
        if (_hasStartedOrFailed) return; // Stop processing once started/failed

        setState(() {
          _outputLines.add(line);
        });

        // Check if app has started successfully (VM Service URI detected)
        if (nonNullInstance.vmServiceUri != null) {
          setState(() {
            _hasStartedOrFailed = true;
          });
          _outputSubscription?.cancel();
          _errorSubscription?.cancel();
        }
      },
      onError: (error) {
        setState(() {
          _outputLines.add('Error: $error');
          _hasStartedOrFailed = true;
        });
        _outputSubscription?.cancel();
        _errorSubscription?.cancel();
      },
      onDone: () {
        if (!_hasStartedOrFailed) {
          setState(() {
            _hasStartedOrFailed = true;
          });
        }
      },
    );

    // Listen to stderr stream
    _errorSubscription = nonNullInstance.errors.listen(
      (line) {
        if (_hasStartedOrFailed) return;

        setState(() {
          _outputLines.add('[stderr] $line');
        });

        // Check for common error patterns that indicate failure
        if (line.toLowerCase().contains('error') ||
            line.toLowerCase().contains('failed') ||
            line.toLowerCase().contains('exception')) {
          setState(() {
            _hasStartedOrFailed = true;
          });
          _outputSubscription?.cancel();
          _errorSubscription?.cancel();
        }
      },
      onError: (error) {
        setState(() {
          _outputLines.add('[stderr] Error: $error');
          _hasStartedOrFailed = true;
        });
        _outputSubscription?.cancel();
        _errorSubscription?.cancel();
      },
    );

    // Also check if instance is no longer running
    if (!nonNullInstance.isRunning) {
      setState(() {
        _hasStartedOrFailed = true;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    // If invocation has an error, use default renderer
    if (component.invocation.isError) {
      return DefaultRenderer(
        invocation: component.invocation,
        workingDirectory: component.workingDirectory,
        executionId: component.executionId,
        agentId: component.agentId,
      );
    }

    // Start listening immediately - we have the tool use ID which becomes the instance ID
    _startListening(context);

    final hasResult = component.invocation.hasResult;
    final statusColor = hasResult ? Colors.green : Colors.yellow;
    final statusIndicator = '●';

    if (_outputLines.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(statusIndicator, style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              Text(
                component.invocation.displayName,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          // Waiting message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⎿  ',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.secondary),
                ),
              ),
              Text(
                'Waiting for Flutter output...',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.secondary),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Show last few lines of output
    final displayLines = _outputLines.length > 5
        ? _outputLines.sublist(_outputLines.length - 5)
        : _outputLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with status
        Row(
          children: [
            Text(statusIndicator, style: TextStyle(color: statusColor)),
            SizedBox(width: 1),
            Text(
              component.invocation.displayName,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        // Output lines
        for (final line in displayLines)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⎿  ',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.secondary),
                ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(
                    color: Colors.white.withOpacity(TextOpacity.secondary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (_hasStartedOrFailed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⎿  ',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.secondary),
                ),
              ),
              Text(
                '(${_outputLines.length} lines total)',
                style: TextStyle(
                  color: Colors.white.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
