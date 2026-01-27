import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:moondream_api/moondream_api.dart';
import 'package:sentry/sentry.dart';
import 'package:uuid/uuid.dart';
import 'flutter_instance.dart';
import 'synthetic_main_generator.dart';
import 'utils/image_resizer.dart';

/// MCP server for managing Flutter application runtime instances
class FlutterRuntimeServer extends McpServerBase {
  static const String serverName = 'flutter-runtime';

  /// Timeout for Moondream API calls
  static const _moondreamTimeout = Duration(seconds: 30);

  final _instances = <String, FlutterInstance>{};
  final _instanceWorkingDirs =
      <String, String>{}; // Track working dirs for cleanup
  final _uuid = const Uuid();
  MoondreamClient? _moondreamClient;

  FlutterRuntimeServer() : super(name: serverName, version: '1.0.0') {
    // Try to initialize Moondream client from environment
    try {
      _moondreamClient = MoondreamClient.fromEnvironment();
    } catch (e) {
      // Moondream not available - flutterAct will fail with clear error
    }
  }

  /// Creates an ImageContent from screenshot bytes, resizing if needed to fit Claude API limits.
  ImageContent _createScreenshotContent(List<int> screenshotBytes) {
    final resizedBytes = resizeImageIfNeeded(screenshotBytes);
    return ImageContent(
      data: base64.encode(resizedBytes),
      mimeType: 'image/png',
    );
  }

  /// Report a flutter runtime operation error to Sentry with context
  Future<void> _reportError(
    Object e,
    StackTrace stackTrace,
    String toolName, {
    String? instanceId,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setTag('mcp_server', serverName);
      scope.setTag('mcp_tool', toolName);
      if (instanceId != null) {
        scope.setContexts('mcp_context', {'instance_id': instanceId});
      }
    });
    await Sentry.captureException(e, stackTrace: stackTrace);
  }

  @override
  List<String> get toolNames => [
    'flutterStart',
    'flutterReload',
    'flutterRestart',
    'flutterStop',
    'flutterList',
    'flutterGetInfo',
    'flutterGetLogs',
    'flutterScreenshot',
    'flutterAct',
    'flutterTapAt',
    'flutterType',
    'flutterScroll',
    'flutterScrollAt',
    'flutterMoveCursor',
    'flutterGetWidgetInfo',
    'flutterGetNavigationState',
    'flutterGetErrors',
    'flutterSetDeviceSize',
    'flutterResetDeviceSize',
    'flutterSetAnimationSpeed',
    'flutterSetThemeMode',
    'flutterGetThemeMode',
    'flutterSetLocale',
    'flutterResetLocale',
  ];

  @override
  void registerTools(McpServer server) {
    // Flutter Start
    server.tool(
      'flutterStart',
      description:
          'Start a Flutter application instance. IMPORTANT: You must pass your tool use ID as the instanceId parameter so the UI can stream output in real-time.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'command': {
            'type': 'string',
            'description':
                'The flutter run command (e.g., "flutter run -d chrome")',
          },
          'workingDirectory': {
            'type': 'string',
            'description':
                'Working directory for the Flutter project (defaults to current directory)',
          },
          'instanceId': {
            'type': 'string',
            'description':
                'REQUIRED: Pass your tool use ID here. This allows the UI to start streaming output immediately.',
          },
        },
        required: ['command', 'instanceId'],
      ),
      callback: ({args, extra}) async {
        final command = args!['command'] as String;
        final workingDirectory =
            args['workingDirectory'] as String? ?? Directory.current.path;
        final instanceId = args['instanceId'] as String? ?? _uuid.v4();

        try {
          // Parse command into parts
          var commandParts = _parseCommand(command);

          // Validate that it's a flutter command
          if (commandParts.isEmpty ||
              (commandParts.first != 'flutter' &&
                  commandParts.first != 'fvm')) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text: 'Error: Command must start with "flutter" or "fvm"',
                ),
              ],
            );
          }

          // Generate synthetic main file for runtime AI dev tools injection
          print(
            '🚀 [FlutterRuntimeServer] Generating synthetic main for runtime AI dev tools...',
          );
          final syntheticMainPath = await SyntheticMainGenerator.generate(
            projectDir: workingDirectory,
          );
          print(
            '🚀 [FlutterRuntimeServer] Synthetic main generated at: $syntheticMainPath',
          );

          // Inject -t flag to point to synthetic main (if not already present)
          final originalCommand = commandParts.join(' ');
          commandParts = _injectTargetFlag(commandParts, syntheticMainPath);
          final modifiedCommand = commandParts.join(' ');
          print('🚀 [FlutterRuntimeServer] Original command: $originalCommand');
          print('🚀 [FlutterRuntimeServer] Modified command: $modifiedCommand');

          // Track working directory for cleanup on stop
          _instanceWorkingDirs[instanceId] = workingDirectory;

          // Start the process
          final process = await Process.start(
            commandParts.first,
            commandParts.sublist(1),
            workingDirectory: workingDirectory,
            mode: ProcessStartMode.normal,
          );

          // Create instance wrapper
          final instance = FlutterInstance(
            id: instanceId,
            process: process,
            workingDirectory: workingDirectory,
            command: commandParts,
            startedAt: DateTime.now(),
          );

          _instances[instanceId] = instance;

          // Set up auto-cleanup when process exits
          instance.process.exitCode.then((_) {
            _instances.remove(instanceId);
          });

          // Wait for Flutter to start or fail
          final startupResult = await instance.waitForStartup();

          if (!startupResult.isSuccess) {
            // Build full output even for failures
            final outputBuffer = StringBuffer();
            outputBuffer.writeln('Flutter instance failed to start!');
            outputBuffer.writeln();
            final errorMessage = startupResult.message ?? 'Unknown error';
            outputBuffer.writeln('Error: $errorMessage');
            outputBuffer.writeln();
            outputBuffer.writeln('Instance ID: $instanceId');
            outputBuffer.writeln('Working Directory: $workingDirectory');
            outputBuffer.writeln('Command: $command');
            outputBuffer.writeln();
            outputBuffer.writeln('=== Flutter Output ===');
            outputBuffer.writeln();

            // Append all buffered output
            for (final line in instance.bufferedOutput) {
              outputBuffer.writeln(line);
            }

            // Append any errors
            if (instance.bufferedErrors.isNotEmpty) {
              outputBuffer.writeln();
              outputBuffer.writeln('=== Errors ===');
              for (final line in instance.bufferedErrors) {
                outputBuffer.writeln(line);
              }
            }

            // Clean up the instance
            _instances.remove(instanceId);
            await instance.stop();

            return CallToolResult.fromContent(
              content: [TextContent(text: outputBuffer.toString())],
            );
          }

          // Build full output with header and all buffered lines
          final outputBuffer = StringBuffer();
          outputBuffer.writeln('Flutter instance started successfully!');
          outputBuffer.writeln();
          outputBuffer.writeln('Instance ID: $instanceId');
          outputBuffer.writeln('Working Directory: $workingDirectory');
          outputBuffer.writeln('Command: $command');
          if (instance.vmServiceUri != null) {
            outputBuffer.writeln('VM Service URI: ${instance.vmServiceUri}');
          }
          if (instance.deviceId != null) {
            outputBuffer.writeln('Device ID: ${instance.deviceId}');
          }
          outputBuffer.writeln();
          outputBuffer.writeln('=== Flutter Output ===');
          outputBuffer.writeln();

          // Append all buffered output
          for (final line in instance.bufferedOutput) {
            outputBuffer.writeln(line);
          }

          // Append any errors
          if (instance.bufferedErrors.isNotEmpty) {
            outputBuffer.writeln();
            outputBuffer.writeln('=== Errors ===');
            for (final line in instance.bufferedErrors) {
              outputBuffer.writeln(line);
            }
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: outputBuffer.toString())],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterStart',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error starting Flutter instance: $e')],
          );
        }
      },
    );

    // Flutter Reload
    server.tool(
      'flutterReload',
      description: 'Perform a hot reload on a running Flutter instance',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance to reload',
          },
          'hot': {
            'type': 'boolean',
            'description':
                'Whether to perform hot reload (true) or hot restart (false)',
            'default': true,
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;
        final hot = args['hot'] as bool? ?? true;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final result = hot
              ? await instance.hotReload()
              : await instance.hotRestart();

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    '''
$result

Instance ID: $instanceId
Type: ${hot ? 'Hot Reload' : 'Hot Restart'}
''',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterReload',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Flutter Restart (convenience method)
    server.tool(
      'flutterRestart',
      description:
          'Perform a hot restart (full restart) on a running Flutter instance',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance to restart',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final result = await instance.hotRestart();

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    '''
$result

Instance ID: $instanceId
''',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterRestart',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Flutter Stop
    server.tool(
      'flutterStop',
      description: 'Stop a running Flutter instance',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance to stop',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          await instance.stop();
          _instances.remove(instanceId);

          // Clean up synthetic main file
          final workingDir = _instanceWorkingDirs.remove(instanceId);
          if (workingDir != null) {
            await SyntheticMainGenerator.cleanup(workingDir);
          }

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    '''
Flutter instance stopped successfully.

Instance ID: $instanceId
''',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterStop',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error stopping instance: $e')],
          );
        }
      },
    );

    // Flutter List
    server.tool(
      'flutterList',
      description: 'List all running Flutter instances',
      toolInputSchema: ToolInputSchema(properties: {}),
      callback: ({args, extra}) async {
        if (_instances.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'No running Flutter instances.')],
          );
        }

        final buffer = StringBuffer('Running Flutter Instances:\n\n');

        for (final instance in _instances.values) {
          buffer.writeln('ID: ${instance.id}');
          buffer.writeln(
            '  Status: ${instance.isRunning ? "Running" : "Stopped"}',
          );
          buffer.writeln('  Started: ${instance.startedAt}');
          buffer.writeln('  Directory: ${instance.workingDirectory}');
          buffer.writeln('  Command: ${instance.command.join(" ")}');
          if (instance.vmServiceUri != null) {
            buffer.writeln('  VM Service: ${instance.vmServiceUri}');
          }
          if (instance.deviceId != null) {
            buffer.writeln('  Device: ${instance.deviceId}');
          }
          buffer.writeln();
        }

        return CallToolResult.fromContent(
          content: [TextContent(text: buffer.toString())],
        );
      },
    );

    // Flutter Get Info
    server.tool(
      'flutterGetInfo',
      description: 'Get detailed information about a specific Flutter instance',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        final info = instance.toJson();
        final buffer = StringBuffer('Flutter Instance Information:\n\n');

        buffer.writeln('ID: ${info['id']}');
        buffer.writeln('Status: ${info['isRunning'] ? "Running" : "Stopped"}');
        buffer.writeln('Started At: ${info['startedAt']}');
        buffer.writeln('Working Directory: ${info['workingDirectory']}');
        buffer.writeln('Command: ${info['command']}');

        if (info['vmServiceUri'] != null) {
          buffer.writeln('VM Service URI: ${info['vmServiceUri']}');
        }

        if (info['deviceId'] != null) {
          buffer.writeln('Device ID: ${info['deviceId']}');
        }

        return CallToolResult.fromContent(
          content: [TextContent(text: buffer.toString())],
        );
      },
    );

    // Flutter Get Logs
    server.tool(
      'flutterGetLogs',
      description:
          'Retrieve logs from a running Flutter instance. Returns buffered stdout and/or stderr output.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'stream': {
            'type': 'string',
            'description':
                'Which output stream to retrieve: "stdout", "stderr", or "both" (default: "both")',
            'enum': ['stdout', 'stderr', 'both'],
          },
          'filter': {
            'type': 'string',
            'description':
                'Optional regex pattern to filter log lines. Only lines matching this pattern will be returned.',
          },
          'lastN': {
            'type': 'integer',
            'description':
                'Optional: Return only the last N lines. If not specified, returns all buffered lines.',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;
        final stream = args['stream'] as String? ?? 'both';
        final filterPattern = args['filter'] as String?;
        final lastN = args['lastN'] as int?;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          // Collect logs based on stream parameter
          var lines = <String>[];

          if (stream == 'stdout' || stream == 'both') {
            lines.addAll(instance.bufferedOutput);
          }

          if (stream == 'stderr' || stream == 'both') {
            // Add stderr with prefix to distinguish from stdout when both are requested
            if (stream == 'both') {
              for (final line in instance.bufferedErrors) {
                lines.add('[stderr] $line');
              }
            } else {
              lines.addAll(instance.bufferedErrors);
            }
          }

          // Apply regex filter if provided
          if (filterPattern != null && filterPattern.isNotEmpty) {
            try {
              final regex = RegExp(filterPattern);
              lines = lines.where((line) => regex.hasMatch(line)).toList();
            } catch (e) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text: 'Error: Invalid regex pattern "$filterPattern": $e',
                  ),
                ],
              );
            }
          }

          // Apply lastN limit if provided
          if (lastN != null && lastN > 0 && lines.length > lastN) {
            lines = lines.sublist(lines.length - lastN);
          }

          // Build response
          final buffer = StringBuffer();
          buffer.writeln('Flutter Instance Logs (${instance.id}):');
          buffer.writeln('Stream: $stream');
          if (filterPattern != null) {
            buffer.writeln('Filter: $filterPattern');
          }
          buffer.writeln('Lines: ${lines.length}');
          buffer.writeln();
          buffer.writeln('=== Output ===');
          buffer.writeln();

          for (final line in lines) {
            buffer.writeln(line);
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: buffer.toString())],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetLogs',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error retrieving logs: $e')],
          );
        }
      },
    );

    // Flutter Screenshot
    server.tool(
      'flutterScreenshot',
      description:
          'Take a screenshot of a running Flutter instance. Use sparingly - prefer flutterGetElements for understanding UI state. Screenshots are useful for: debugging visual issues, verifying layouts, or when semantic info is insufficient.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance to screenshot',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String;

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final screenshotBytes = await instance.screenshot();

          if (screenshotBytes == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Failed to capture screenshot. Ensure the Flutter app is running in debug/profile mode and VM Service is available.',
                ),
              ],
            );
          }

          // Return the screenshot as an image content block with base64 encoded data
          return CallToolResult.fromContent(
            content: [_createScreenshotContent(screenshotBytes)],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScreenshot',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error taking screenshot: $e')],
          );
        }
      },
    );

    // Flutter Act - Natural language element location using Moondream
    server.tool(
      'flutterAct',
      description:
          'Perform an action on a Flutter UI element by describing it in natural language. Uses vision AI (Moondream) to locate the element. PREFER flutterGetElements + flutterTapElement instead - they are faster and more reliable. Use flutterAct only when elements lack proper semantics/labels.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'action': {
            'type': 'string',
            'description':
                'Action to perform. Currently supported: "click" or "tap"',
            'enum': ['click', 'tap'],
          },
          'description': {
            'type': 'string',
            'description':
                'Natural language description of the UI element to interact with (e.g., "login button", "email input field", "submit form").',
          },
        },
        required: ['instanceId', 'action', 'description'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final action = args['action'] as String?;
        final description = args['description'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (action == null || (action != 'click' && action != 'tap')) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: action must be "click" or "tap"'),
            ],
          );
        }

        if (description == null || description.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: description is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          // Check if Moondream is available
          if (_moondreamClient == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Moondream API not available. Set MOONDREAM_API_KEY environment variable. Alternatively, use flutterTapAt to tap at specific coordinates.',
                ),
              ],
            );
          }

          // Step 1: Take screenshot
          final screenshotBytes = await instance.screenshot();
          if (screenshotBytes == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Failed to capture screenshot'),
              ],
            );
          }

          // Step 2: Encode screenshot for Moondream
          final imageUrl = ImageEncoder.encodeBytes(
            Uint8List.fromList(screenshotBytes),
            mimeType: 'image/png',
          );

          // Step 3: Use Moondream's point API to find the element coordinates
          final pointResponse = await _moondreamClient!
              .point(imageUrl: imageUrl, object: description)
              .timeout(
                _moondreamTimeout,
                onTimeout: () => throw TimeoutException(
                  'Moondream point API timed out after ${_moondreamTimeout.inSeconds}s',
                ),
              );

          // Get normalized coordinates (0-1 range)
          final moondreamX = pointResponse.x;
          final moondreamY = pointResponse.y;

          // Validate coordinates
          if (moondreamX == null || moondreamY == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Moondream could not find "$description" (no points returned). The element may not be visible or recognizable. Use flutterTapAt to tap at specific coordinates as a fallback.',
                ),
              ],
            );
          }

          if (moondreamX.isNaN ||
              moondreamY.isNaN ||
              moondreamX < 0 ||
              moondreamY < 0 ||
              moondreamX > 1 ||
              moondreamY > 1) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Moondream returned invalid normalized coordinates: ($moondreamX, $moondreamY). Use flutterTapAt to tap at specific coordinates as a fallback.',
                ),
              ],
            );
          }

          final normalizedX = moondreamX;
          final normalizedY = moondreamY;

          // Decode PNG to get dimensions
          final bytes = Uint8List.fromList(screenshotBytes);
          if (bytes.length < 24 ||
              bytes[0] != 0x89 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x4E ||
              bytes[3] != 0x47) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Invalid PNG format from screenshot'),
              ],
            );
          }

          // Read width and height from PNG header (big-endian)
          final width =
              (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final height =
              (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];

          print(
            '🖼️  [FlutterRuntimeServer] Screenshot dimensions: ${width}x$height',
          );
          print('   Normalized coordinates: ($normalizedX, $normalizedY)');

          // Convert normalized coordinates to physical pixel coordinates
          final pixelRatioX = (normalizedX * width).round().toDouble();
          final pixelRatioY = (normalizedY * height).round().toDouble();

          print('   Physical pixel coordinates: ($pixelRatioX, $pixelRatioY)');

          // Divide by devicePixelRatio to get logical pixels
          // Use the instance's devicePixelRatio (from last screenshot) for accurate conversion
          final devicePixelRatio = instance.devicePixelRatio;
          final x = (pixelRatioX / devicePixelRatio).round().toDouble();
          final y = (pixelRatioY / devicePixelRatio).round().toDouble();

          print('   Logical pixel coordinates (÷$devicePixelRatio): ($x, $y)');
          print('   🎯 CALLING instance.tap($x, $y)');

          // Step 4: Perform tap
          final success = await instance.tap(x, y);

          if (success) {
            // Automatically get updated elements after action
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Tap failed')],
            );
          }
        } on MoondreamAuthenticationException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterAct',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: Moondream authentication failed. Check your API key: ${e.message}',
              ),
            ],
          );
        } on MoondreamRateLimitException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterAct',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Moondream rate limit exceeded: ${e.message}',
              ),
            ],
          );
        } on MoondreamException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterAct',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Moondream API error: ${e.message}'),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterAct',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Failed to perform action: $e\n$stackTrace',
              ),
            ],
          );
        }
      },
    );

    // Flutter Tap At - Direct coordinate-based taps
    server.tool(
      'flutterTapAt',
      description:
          'Tap at specific coordinates on a Flutter app. Use normalized coordinates (0-1) where (0,0) is top-left and (1,1) is bottom-right. Useful when you know the exact position or as a fallback when natural language detection fails. Returns a screenshot after the tap.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'x': {
            'type': 'number',
            'description':
                'X coordinate (0-1 normalized). 0 is left edge, 1 is right edge.',
          },
          'y': {
            'type': 'number',
            'description':
                'Y coordinate (0-1 normalized). 0 is top edge, 1 is bottom edge.',
          },
        },
        required: ['instanceId', 'x', 'y'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final rawX = args['x'];
        final rawY = args['y'];

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final coordinateX = rawX is num ? rawX.toDouble() : null;
        final coordinateY = rawY is num ? rawY.toDouble() : null;

        if (coordinateX == null || coordinateY == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: x and y must be valid numbers'),
            ],
          );
        }

        if (coordinateX < 0 ||
            coordinateX > 1 ||
            coordinateY < 0 ||
            coordinateY > 1) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: x and y must be normalized coordinates between 0 and 1',
              ),
            ],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '🎯 [FlutterRuntimeServer] Using direct coordinates: ($coordinateX, $coordinateY)',
          );

          // Take screenshot for dimensions
          final screenshotBytes = await instance.screenshot();
          if (screenshotBytes == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Failed to capture screenshot for coordinate conversion',
                ),
              ],
            );
          }

          // Decode PNG to get dimensions
          final bytes = Uint8List.fromList(screenshotBytes);
          if (bytes.length < 24 ||
              bytes[0] != 0x89 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x4E ||
              bytes[3] != 0x47) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Invalid PNG format from screenshot'),
              ],
            );
          }

          // Read width and height from PNG header (big-endian)
          final width =
              (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final height =
              (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];

          print(
            '🖼️  [FlutterRuntimeServer] Screenshot dimensions: ${width}x$height',
          );
          print('   Normalized coordinates: ($coordinateX, $coordinateY)');

          // Convert normalized coordinates to physical pixel coordinates
          final pixelRatioX = (coordinateX * width).round().toDouble();
          final pixelRatioY = (coordinateY * height).round().toDouble();

          print('   Physical pixel coordinates: ($pixelRatioX, $pixelRatioY)');

          // Divide by devicePixelRatio to get logical pixels
          // Use the instance's devicePixelRatio (from last screenshot) for accurate conversion
          final devicePixelRatio = instance.devicePixelRatio;
          final x = (pixelRatioX / devicePixelRatio).round().toDouble();
          final y = (pixelRatioY / devicePixelRatio).round().toDouble();

          print('   Logical pixel coordinates (÷$devicePixelRatio): ($x, $y)');
          print('   🎯 CALLING instance.tap($x, $y)');

          // Perform tap
          final success = await instance.tap(x, y);

          if (success) {
            // Automatically get updated elements after tap
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Tap failed')],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterTapAt',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Failed to perform tap: $e\n$stackTrace',
              ),
            ],
          );
        }
      },
    );

    // Flutter Get Elements - Get all actionable UI elements
    server.tool(
      'flutterGetElements',
      description:
          'Get all visible actionable UI elements (buttons, text fields, checkboxes, etc.) in the Flutter app. This is the PRIMARY tool for understanding the UI state - use it instead of screenshots. Returns element IDs for use with flutterTapElement. Only elements on the current screen/route are returned (Navigator routes are properly filtered).',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final result = await instance.getActionableElements();
          return CallToolResult.fromContent(
            content: [TextContent(text: _formatElements(result))],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetElements',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: Failed to get elements: $e')],
          );
        }
      },
    );

    // Flutter Tap Element - Tap an element by ID
    server.tool(
      'flutterTapElement',
      description:
          'Tap an element by its ID from flutterGetElements. This is the PREFERRED way to interact with UI - faster and more reliable than vision AI. Call flutterGetElements after to verify the action worked.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'elementId': {
            'type': 'string',
            'description':
                'ID of the element to tap (e.g., "button_0", "textfield_1"). Get IDs from flutterGetElements.',
          },
        },
        required: ['instanceId', 'elementId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final elementId = args['elementId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (elementId == null || elementId.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: elementId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print('🎯 [FlutterRuntimeServer] Tapping element: $elementId');

          final success = await instance.tapElement(elementId);

          if (success) {
            // Automatically get updated elements after tap
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Tap failed')],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterTapElement',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: Failed to tap element: $e')],
          );
        }
      },
    );

    // Flutter Type - Type text into focused input
    server.tool(
      'flutterType',
      description:
          'Type text into the currently focused input field. Supports special keys: {backspace}, {enter}, {tab}, {escape}, {left}, {right}, {up}, {down}. Characters are typed one by one so the user can see the typing animation.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'text': {
            'type': 'string',
            'description':
                'Text to type. Use {backspace}, {enter}, {tab}, {escape}, {left}, {right}, {up}, {down} for special keys. Example: "Hello{enter}" or "test{backspace}{backspace}ab"',
          },
        },
        required: ['instanceId', 'text'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final text = args['text'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (text == null || text.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: text is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print('⌨️  [FlutterRuntimeServer] Typing text: "$text"');

          final success = await instance.type(text);

          if (success) {
            // Automatically get updated elements after typing
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Type failed')],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterType',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to type text: $e\n$stackTrace'),
            ],
          );
        }
      },
    );

    // Flutter Scroll - Semantic scroll using Moondream
    server.tool(
      'flutterScroll',
      description:
          'Scroll in the Flutter app using natural language description. Uses AI vision to determine the scroll area and direction. Examples: "scroll down to see more items", "scroll the horizontal list to the right", "scroll up to the top"',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'instruction': {
            'type': 'string',
            'description': 'Natural language description of the scroll action',
          },
        },
        required: ['instanceId', 'instruction'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final instruction = args['instruction'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (instruction == null || instruction.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instruction is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          // Check if Moondream is available
          if (_moondreamClient == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Moondream API not available. Set MOONDREAM_API_KEY environment variable. Alternatively, use flutterScrollAt to scroll at specific coordinates.',
                ),
              ],
            );
          }

          // Step 1: Take screenshot
          final screenshotBytes = await instance.screenshot();
          if (screenshotBytes == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Failed to capture screenshot'),
              ],
            );
          }

          // Step 2: Encode screenshot for Moondream
          final imageUrl = ImageEncoder.encodeBytes(
            Uint8List.fromList(screenshotBytes),
            mimeType: 'image/png',
          );

          // Step 3: Use Moondream to analyze the scroll intent
          // Ask for: center of scrollable area and scroll direction
          final queryResponse = await _moondreamClient!
              .query(
                imageUrl: imageUrl,
                question:
                    '''Analyze this screenshot and the user's scroll instruction: "$instruction"

Respond with ONLY a JSON object in this exact format (no markdown, no explanation):
{"startX": 0.5, "startY": 0.5, "dx": 0.0, "dy": -0.3}

Where:
- startX, startY: normalized coordinates (0-1) of the center of the scrollable area
- dx, dy: scroll direction and amount as normalized values (-1 to 1). Positive dy = scroll down (drag up), negative dy = scroll up (drag down). Positive dx = scroll right, negative dx = scroll left.

For example:
- "scroll down" -> {"startX": 0.5, "startY": 0.5, "dx": 0.0, "dy": 0.3}
- "scroll up" -> {"startX": 0.5, "startY": 0.5, "dx": 0.0, "dy": -0.3}
- "scroll right" -> {"startX": 0.5, "startY": 0.5, "dx": 0.3, "dy": 0.0}''',
              )
              .timeout(
                _moondreamTimeout,
                onTimeout: () => throw TimeoutException(
                  'Moondream query API timed out after ${_moondreamTimeout.inSeconds}s',
                ),
              );

          print(
            '📥 [FlutterRuntimeServer] Moondream response: ${queryResponse.answer}',
          );

          // Parse the JSON response
          Map<String, dynamic> scrollParams;
          try {
            // Clean the response - remove any markdown formatting
            var answer = queryResponse.answer.trim();
            if (answer.startsWith('```')) {
              answer = answer
                  .replaceAll(RegExp(r'^```\w*\n?'), '')
                  .replaceAll(RegExp(r'\n?```$'), '');
            }
            scrollParams = json.decode(answer) as Map<String, dynamic>;
          } catch (e) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Failed to parse Moondream response: ${queryResponse.answer}. Use flutterScrollAt for precise control.',
                ),
              ],
            );
          }

          final normalizedStartX =
              (scrollParams['startX'] as num?)?.toDouble() ?? 0.5;
          final normalizedStartY =
              (scrollParams['startY'] as num?)?.toDouble() ?? 0.5;
          final normalizedDx = (scrollParams['dx'] as num?)?.toDouble() ?? 0.0;
          final normalizedDy = (scrollParams['dy'] as num?)?.toDouble() ?? 0.0;

          // Validate coordinates
          if (normalizedStartX < 0 ||
              normalizedStartX > 1 ||
              normalizedStartY < 0 ||
              normalizedStartY > 1) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Invalid start coordinates from Moondream. Use flutterScrollAt for precise control.',
                ),
              ],
            );
          }

          // Decode PNG to get dimensions
          final bytes = Uint8List.fromList(screenshotBytes);
          if (bytes.length < 24 ||
              bytes[0] != 0x89 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x4E ||
              bytes[3] != 0x47) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Invalid PNG format from screenshot'),
              ],
            );
          }

          // Read width and height from PNG header (big-endian)
          final width =
              (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final height =
              (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];

          print(
            '🖼️  [FlutterRuntimeServer] Screenshot dimensions: ${width}x$height',
          );

          // Convert normalized coordinates to physical pixel coordinates
          final pixelStartX = (normalizedStartX * width).round().toDouble();
          final pixelStartY = (normalizedStartY * height).round().toDouble();
          // Scroll distance based on screen dimensions (use smaller dimension for reference)
          final scrollMagnitude = (width < height ? width : height) * 0.4;
          final pixelDx = (normalizedDx * scrollMagnitude).round().toDouble();
          final pixelDy = (normalizedDy * scrollMagnitude).round().toDouble();

          // Divide by devicePixelRatio to get logical pixels
          // Use the instance's devicePixelRatio (from last screenshot) for accurate conversion
          final devicePixelRatio = instance.devicePixelRatio;
          final startX = (pixelStartX / devicePixelRatio).round().toDouble();
          final startY = (pixelStartY / devicePixelRatio).round().toDouble();
          final dx = (pixelDx / devicePixelRatio).round().toDouble();
          final dy = (pixelDy / devicePixelRatio).round().toDouble();

          print(
            '   Logical scroll: start=($startX, $startY), delta=($dx, $dy)',
          );

          // Perform scroll
          final success = await instance.scroll(
            startX: startX,
            startY: startY,
            dx: dx,
            dy: dy,
            durationMs: 300,
          );

          if (success) {
            // Automatically get updated elements after scroll
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Scroll failed')],
            );
          }
        } on MoondreamAuthenticationException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScroll',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: Moondream authentication failed. Check your API key: ${e.message}',
              ),
            ],
          );
        } on MoondreamRateLimitException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScroll',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Moondream rate limit exceeded: ${e.message}',
              ),
            ],
          );
        } on MoondreamException catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScroll',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Moondream API error: ${e.message}'),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScroll',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Failed to perform scroll: $e\n$stackTrace',
              ),
            ],
          );
        }
      },
    );

    // Flutter Scroll At - Precise coordinate-based scrolling
    server.tool(
      'flutterScrollAt',
      description:
          'Scroll at specific coordinates with precise control. Uses normalized coordinates (0-1) for start position and relative amounts for scroll distance.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'startX': {
            'type': 'number',
            'description':
                'Starting X position (0-1 normalized, 0=left, 1=right)',
          },
          'startY': {
            'type': 'number',
            'description':
                'Starting Y position (0-1 normalized, 0=top, 1=bottom)',
          },
          'dx': {
            'type': 'number',
            'description':
                'Horizontal scroll amount (-1 to 1, negative=left, positive=right)',
          },
          'dy': {
            'type': 'number',
            'description':
                'Vertical scroll amount (-1 to 1, negative=up, positive=down)',
          },
          'durationMs': {
            'type': 'number',
            'description':
                'Duration of scroll animation in milliseconds (default: 300)',
          },
        },
        required: ['instanceId', 'startX', 'startY', 'dx', 'dy'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final rawStartX = args['startX'];
        final rawStartY = args['startY'];
        final rawDx = args['dx'];
        final rawDy = args['dy'];
        final rawDurationMs = args['durationMs'];

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final normalizedStartX = rawStartX is num ? rawStartX.toDouble() : null;
        final normalizedStartY = rawStartY is num ? rawStartY.toDouble() : null;
        final normalizedDx = rawDx is num ? rawDx.toDouble() : null;
        final normalizedDy = rawDy is num ? rawDy.toDouble() : null;
        final durationMs = rawDurationMs is num ? rawDurationMs.toInt() : 300;

        if (normalizedStartX == null ||
            normalizedStartY == null ||
            normalizedDx == null ||
            normalizedDy == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: startX, startY, dx, and dy must be valid numbers',
              ),
            ],
          );
        }

        if (normalizedStartX < 0 ||
            normalizedStartX > 1 ||
            normalizedStartY < 0 ||
            normalizedStartY > 1) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: startX and startY must be normalized coordinates between 0 and 1',
              ),
            ],
          );
        }

        if (normalizedDx < -1 ||
            normalizedDx > 1 ||
            normalizedDy < -1 ||
            normalizedDy > 1) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: dx and dy must be between -1 and 1'),
            ],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '📜 [FlutterRuntimeServer] ScrollAt: start=($normalizedStartX, $normalizedStartY), delta=($normalizedDx, $normalizedDy)',
          );

          // Take screenshot for dimensions
          final screenshotBytes = await instance.screenshot();
          if (screenshotBytes == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Failed to capture screenshot for coordinate conversion',
                ),
              ],
            );
          }

          // Decode PNG to get dimensions
          final bytes = Uint8List.fromList(screenshotBytes);
          if (bytes.length < 24 ||
              bytes[0] != 0x89 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x4E ||
              bytes[3] != 0x47) {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Invalid PNG format from screenshot'),
              ],
            );
          }

          // Read width and height from PNG header (big-endian)
          final width =
              (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final height =
              (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];

          print(
            '🖼️  [FlutterRuntimeServer] Screenshot dimensions: ${width}x$height',
          );

          // Convert normalized coordinates to physical pixel coordinates
          final pixelStartX = (normalizedStartX * width).round().toDouble();
          final pixelStartY = (normalizedStartY * height).round().toDouble();
          // Scroll distance based on screen dimensions
          final pixelDx = (normalizedDx * width).round().toDouble();
          final pixelDy = (normalizedDy * height).round().toDouble();

          // Divide by devicePixelRatio to get logical pixels
          // Use the instance's devicePixelRatio (from last screenshot) for accurate conversion
          final devicePixelRatio = instance.devicePixelRatio;
          final startX = (pixelStartX / devicePixelRatio).round().toDouble();
          final startY = (pixelStartY / devicePixelRatio).round().toDouble();
          final dx = (pixelDx / devicePixelRatio).round().toDouble();
          final dy = (pixelDy / devicePixelRatio).round().toDouble();

          print(
            '   Logical scroll: start=($startX, $startY), delta=($dx, $dy)',
          );

          // Perform scroll
          final success = await instance.scroll(
            startX: startX,
            startY: startY,
            dx: dx,
            dy: dy,
            durationMs: durationMs,
          );

          if (success) {
            // Automatically get updated elements after scroll
            final updatedElements = await instance.getActionableElements();
            return CallToolResult.fromContent(
              content: [TextContent(text: _formatElements(updatedElements))],
            );
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Scroll failed')],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterScrollAt',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Failed to perform scroll: $e\n$stackTrace',
              ),
            ],
          );
        }
      },
    );

    // Flutter Move Cursor - Move cursor to a position (using coordinates OR Moondream description)
    server.tool(
      'flutterMoveCursor',
      description:
          'Move the cursor to a specific position in the Flutter app. You can specify coordinates directly OR use a natural language description to locate an element with vision AI. The cursor position is used by flutterGetWidgetInfo and shown in screenshots.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'x': {
            'type': 'number',
            'description':
                'X coordinate in normalized screen space (0.0 to 1.0). Optional if description is provided.',
          },
          'y': {
            'type': 'number',
            'description':
                'Y coordinate in normalized screen space (0.0 to 1.0). Optional if description is provided.',
          },
          'description': {
            'type': 'string',
            'description':
                'Natural language description of the UI element to move cursor to (e.g., "login button", "email input field"). Uses vision AI to locate. Optional if x/y are provided.',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final normalizedX = (args['x'] as num?)?.toDouble();
        final normalizedY = (args['y'] as num?)?.toDouble();
        final description = args['description'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          double logicalX;
          double logicalY;
          String locationSource;

          // If coordinates provided, use them directly
          if (normalizedX != null && normalizedY != null) {
            if (normalizedX < 0 ||
                normalizedX > 1 ||
                normalizedY < 0 ||
                normalizedY > 1) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text:
                        'Error: Coordinates must be normalized (0.0 to 1.0). Got x=$normalizedX, y=$normalizedY',
                  ),
                ],
              );
            }

            // Take screenshot to get dimensions for coordinate conversion
            final screenshotBytes = await instance.screenshot();
            if (screenshotBytes == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text:
                        'Error: Failed to capture screenshot for coordinate conversion',
                  ),
                ],
              );
            }

            // Decode PNG to get dimensions
            final bytes = Uint8List.fromList(screenshotBytes);
            if (bytes.length < 24 ||
                bytes[0] != 0x89 ||
                bytes[1] != 0x50 ||
                bytes[2] != 0x4E ||
                bytes[3] != 0x47) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text: 'Error: Invalid PNG format from screenshot',
                  ),
                ],
              );
            }

            final width =
                (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];
            final height =
                (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];

            final pixelX = (normalizedX * width).round().toDouble();
            final pixelY = (normalizedY * height).round().toDouble();
            final devicePixelRatio = instance.devicePixelRatio;
            logicalX = (pixelX / devicePixelRatio).round().toDouble();
            logicalY = (pixelY / devicePixelRatio).round().toDouble();
            locationSource = 'coordinates ($normalizedX, $normalizedY)';
          }
          // If description provided, use Moondream to locate
          else if (description != null && description.isNotEmpty) {
            if (_moondreamClient == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text:
                        'Error: Moondream API not available. Set MOONDREAM_API_KEY environment variable. Use x/y coordinates instead.',
                  ),
                ],
              );
            }

            // Take screenshot for Moondream
            final screenshotBytes = await instance.screenshot();
            if (screenshotBytes == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(text: 'Error: Failed to capture screenshot'),
                ],
              );
            }

            // Encode screenshot for Moondream
            final imageUrl = ImageEncoder.encodeBytes(
              Uint8List.fromList(screenshotBytes),
              mimeType: 'image/png',
            );

            // Query Moondream for element location
            print(
              '🔍 [FlutterRuntimeServer] Asking Moondream to locate: "$description"',
            );
            final pointResponse = await _moondreamClient!
                .point(imageUrl: imageUrl, object: description)
                .timeout(_moondreamTimeout);

            // Get normalized coordinates (0-1 range)
            final moondreamX = pointResponse.x;
            final moondreamY = pointResponse.y;

            print(
              '📍 [FlutterRuntimeServer] Moondream response: x=$moondreamX, y=$moondreamY',
            );

            if (moondreamX == null || moondreamY == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text:
                        'Error: Could not locate "$description" in the screenshot. Try a different description or use coordinates.',
                  ),
                ],
              );
            }

            // Moondream returns normalized coordinates (0-1)
            final bytes = Uint8List.fromList(screenshotBytes);
            final width =
                (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];
            final height =
                (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];

            final pixelX = (moondreamX * width).round().toDouble();
            final pixelY = (moondreamY * height).round().toDouble();
            final devicePixelRatio = instance.devicePixelRatio;
            logicalX = (pixelX / devicePixelRatio).round().toDouble();
            logicalY = (pixelY / devicePixelRatio).round().toDouble();
            locationSource = 'vision AI for "$description"';
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: Either x/y coordinates OR description must be provided',
                ),
              ],
            );
          }

          // Move the cursor
          await instance.moveCursor(logicalX, logicalY);

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Cursor moved to ($logicalX, $logicalY) using $locationSource. Use flutterGetWidgetInfo to inspect widgets at this position.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterMoveCursor',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: Failed to move cursor: $e')],
          );
        }
      },
    );

    // Flutter Get Widget Info - Get widget information at current cursor position
    server.tool(
      'flutterGetWidgetInfo',
      description:
          'Get information about widgets at the current cursor position. Returns widget types, bounds, source file locations (if available), and widget-specific properties like text content. Use flutterMoveCursor first to position the cursor, or this will use the last tap/cursor position.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          // Get the current cursor position
          final cursorPos = await instance.getCursorPosition();

          if (cursorPos == null) {
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      'Error: No cursor position set. Use flutterMoveCursor or flutterTapAt first to position the cursor.',
                ),
              ],
            );
          }

          print(
            '🔍 [FlutterRuntimeServer] Getting widget info at cursor position (${cursorPos.x}, ${cursorPos.y})',
          );

          // Get widget info at the cursor position
          final widgetInfo = await instance.getWidgetInfo(
            cursorPos.x,
            cursorPos.y,
          );

          // Format the response
          final widgets = widgetInfo['widgets'] as List<dynamic>? ?? [];
          final buffer = StringBuffer();
          buffer.writeln(
            'Widget Info at cursor (${cursorPos.x}, ${cursorPos.y}):',
          );
          buffer.writeln('');

          if (widgets.isEmpty) {
            buffer.writeln('No widgets found at this position.');
          } else {
            buffer.writeln('Found ${widgets.length} widget(s):');
            buffer.writeln('');

            for (var i = 0; i < widgets.length; i++) {
              final widget = widgets[i] as Map<String, dynamic>;
              buffer.writeln('${i + 1}. ${widget['type']}');

              if (widget['key'] != null) {
                buffer.writeln('   Key: ${widget['key']}');
              }

              if (widget['text'] != null) {
                buffer.writeln('   Text: "${widget['text']}"');
              }

              if (widget['bounds'] != null) {
                final bounds = widget['bounds'] as Map<String, dynamic>;
                buffer.writeln(
                  '   Bounds: (${bounds['x']?.toStringAsFixed(1)}, ${bounds['y']?.toStringAsFixed(1)}) ${bounds['width']?.toStringAsFixed(1)}x${bounds['height']?.toStringAsFixed(1)}',
                );
              }

              if (widget['creationLocation'] != null) {
                final loc = widget['creationLocation'] as Map<String, dynamic>;
                if (loc['file'] != null) {
                  buffer.writeln('   Source: ${loc['file']}:${loc['line']}');
                } else if (loc['debug'] != null) {
                  buffer.writeln('   Debug: ${loc['debug']}');
                }
              }

              if (widget['creatorChain'] != null) {
                buffer.writeln('   Creator: ${widget['creatorChain']}');
              }

              buffer.writeln('');
            }
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: buffer.toString())],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetWidgetInfo',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to get widget info: $e'),
            ],
          );
        }
      },
    );

    // Flutter Get Navigation State - Get current navigation state
    server.tool(
      'flutterGetNavigationState',
      description:
          'Get the current navigation state of a Flutter app. Returns the current route, route stack, whether back navigation is possible, and count of modal routes. Useful for understanding the navigation context.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final result = await instance.getNavigationState();

          // Format the response
          final buffer = StringBuffer();
          buffer.writeln('Navigation State:');
          buffer.writeln('');
          buffer.writeln('Current Route: ${result['currentRoute'] ?? '(none)'}');
          buffer.writeln('Can Go Back: ${result['canGoBack']}');
          buffer.writeln('Modal Routes: ${result['modalRoutes']}');
          buffer.writeln('');

          final routeStack = result['routeStack'] as List<dynamic>? ?? [];
          if (routeStack.isNotEmpty) {
            buffer.writeln('Route Stack:');
            for (var i = 0; i < routeStack.length; i++) {
              final prefix = i == routeStack.length - 1 ? '→ ' : '  ';
              buffer.writeln('$prefix${routeStack[i]}');
            }
          } else {
            buffer.writeln('Route Stack: (empty)');
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: buffer.toString())],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetNavigationState',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to get navigation state: $e'),
            ],
          );
        }
      },
    );

    // Flutter Get Errors - Get captured errors from the app
    server.tool(
      'flutterGetErrors',
      description:
          'Get captured errors from a running Flutter app. Error capture must be enabled first via this tool. Returns Flutter framework errors and async errors with timestamps, messages, and stack traces. Use this to diagnose issues during testing.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'enable': {
            'type': 'boolean',
            'description':
                'Set to true to enable error capture, false to disable. If not specified, just retrieves errors.',
          },
          'clear': {
            'type': 'boolean',
            'description':
                'Whether to clear the error buffer after retrieval. Defaults to true.',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final enable = args['enable'] as bool?;
        final clear = args['clear'] as bool? ?? true;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          // Handle enable/disable if specified
          if (enable != null) {
            await instance.enableErrorCapture(enabled: enable);
            if (!enable) {
              return CallToolResult.fromContent(
                content: [TextContent(text: 'Error capture disabled.')],
              );
            }
          }

          // Get errors
          final result = await instance.getErrors(clear: clear);
          final errors = result['errors'] as List<dynamic>? ?? [];
          final count = result['count'] as int? ?? 0;

          // Format the response
          final buffer = StringBuffer();
          if (enable == true) {
            buffer.writeln('Error capture enabled.');
            buffer.writeln('');
          }
          buffer.writeln('Captured Errors: $count');
          buffer.writeln('');

          if (errors.isEmpty) {
            buffer.writeln('No errors captured.');
          } else {
            for (var i = 0; i < errors.length; i++) {
              final error = errors[i] as Map<String, dynamic>;
              buffer.writeln('--- Error ${i + 1} ---');
              buffer.writeln('Type: ${error['type']}');
              buffer.writeln('Time: ${error['timestamp']}');
              buffer.writeln('Message: ${error['message']}');
              if (error['context'] != null) {
                buffer.writeln('Context: ${error['context']}');
              }
              if (error['library'] != null) {
                buffer.writeln('Library: ${error['library']}');
              }
              if (error['stackTrace'] != null &&
                  (error['stackTrace'] as String).isNotEmpty) {
                buffer.writeln('Stack Trace:');
                // Limit stack trace to first 10 lines
                final stackLines =
                    (error['stackTrace'] as String).split('\n').take(10);
                for (final line in stackLines) {
                  buffer.writeln('  $line');
                }
                if ((error['stackTrace'] as String).split('\n').length > 10) {
                  buffer.writeln('  ... (truncated)');
                }
              }
              buffer.writeln('');
            }
          }

          if (clear && count > 0) {
            buffer.writeln('(Error buffer cleared)');
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: buffer.toString())],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetErrors',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: Failed to get errors: $e')],
          );
        }
      },
    );

    // Flutter Set Device Size - Override device size for responsive testing
    server.tool(
      'flutterSetDeviceSize',
      description:
          'Set a custom device size for responsive testing. Uses MediaQuery override so the app responds to breakpoints as if on the target device. Choose from presets (iphone-se, iphone-14, ipad-pro-11, pixel-7, desktop-hd, etc.) or specify custom width/height.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'preset': {
            'type': 'string',
            'description':
                'Device preset name. Options: iphone-se, iphone-14, iphone-14-pro-max, iphone-landscape, ipad-mini, ipad-pro-11, ipad-pro-12.9, pixel-7, pixel-fold, desktop-hd, desktop-full-hd, desktop-2k',
            'enum': [
              'iphone-se',
              'iphone-14',
              'iphone-14-pro-max',
              'iphone-landscape',
              'ipad-mini',
              'ipad-pro-11',
              'ipad-pro-12.9',
              'pixel-7',
              'pixel-fold',
              'desktop-hd',
              'desktop-full-hd',
              'desktop-2k',
            ],
          },
          'width': {
            'type': 'number',
            'description':
                'Custom width in logical pixels. Use instead of preset for custom sizes.',
          },
          'height': {
            'type': 'number',
            'description':
                'Custom height in logical pixels. Use instead of preset for custom sizes.',
          },
          'devicePixelRatio': {
            'type': 'number',
            'description':
                'Device pixel ratio (default 1.0). Higher values simulate higher DPI screens.',
          },
          'showFrame': {
            'type': 'boolean',
            'description':
                'Whether to show a visual device frame around the app (default true)',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final preset = args['preset'] as String?;
        final width = (args['width'] as num?)?.toDouble();
        final height = (args['height'] as num?)?.toDouble();
        final devicePixelRatio = (args['devicePixelRatio'] as num?)?.toDouble();
        final showFrame = args['showFrame'] as bool? ?? true;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        // Validate that either preset or width+height is provided
        if (preset == null && (width == null || height == null)) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Error: Either preset or both width and height must be provided',
              ),
            ],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '📱 [FlutterRuntimeServer] Setting device size for instance $instanceId',
          );

          final result = await instance.setDeviceSize(
            preset: preset,
            width: width,
            height: height,
            devicePixelRatio: devicePixelRatio,
            showFrame: showFrame,
          );

          final appliedWidth = result['width'];
          final appliedHeight = result['height'];
          final appliedDpr = result['devicePixelRatio'];

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    '''Device size set successfully!

Size: ${appliedWidth}x$appliedHeight @ ${appliedDpr}x
Frame: ${result['showFrame']}

The app is now running in a simulated ${preset ?? 'custom'} viewport.
Breakpoints and MediaQuery will respond to the new size.''',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterSetDeviceSize',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to set device size: $e'),
            ],
          );
        }
      },
    );

    // Flutter Reset Device Size - Reset to native device size
    server.tool(
      'flutterResetDeviceSize',
      description:
          'Reset the device size to native. Clears any device size override and returns to the actual device dimensions.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '📱 [FlutterRuntimeServer] Resetting device size for instance $instanceId',
          );

          await instance.resetDeviceSize();

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Device size reset to native. The app is now using the actual device dimensions.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterResetDeviceSize',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to reset device size: $e'),
            ],
          );
        }
      },
    );

    // Flutter Set Animation Speed - Control animation speed
    server.tool(
      'flutterSetAnimationSpeed',
      description:
          'Control the animation speed of the Flutter app. Use slow motion to observe animations or pause for static screenshots.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'speed': {
            'type': 'string',
            'description':
                'Speed preset: normal (1x), slow (0.25x), very-slow (0.1x), paused',
            'enum': ['normal', 'slow', 'very-slow', 'paused'],
          },
          'customFactor': {
            'type': 'number',
            'description':
                'Custom time dilation factor. 1.0=normal, 4.0=4x slower, etc.',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final speed = args['speed'] as String?;
        final customFactor = (args['customFactor'] as num?)?.toDouble();

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        // Determine the factor to use
        double factor;
        if (customFactor != null) {
          factor = customFactor;
        } else if (speed != null) {
          switch (speed) {
            case 'normal':
              factor = 1.0;
            case 'slow':
              factor = 4.0; // 0.25x speed
            case 'very-slow':
              factor = 10.0; // 0.1x speed
            case 'paused':
              factor = 1000000.0; // effectively paused
            default:
              factor = 1.0;
          }
        } else {
          factor = 1.0;
        }

        try {
          print(
            '🎬 [FlutterRuntimeServer] Setting animation speed for instance $instanceId (factor: $factor)',
          );

          await instance.setTimeDilation(factor);

          final description = customFactor != null
              ? '${factor}x time dilation'
              : speed ?? 'normal';

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Animation speed set to $description. Animations will now run ${factor > 1 ? "${factor}x slower" : "at normal speed"}.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterSetAnimationSpeed',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to set animation speed: $e'),
            ],
          );
        }
      },
    );

    // Flutter Set Theme Mode - Switch between light/dark/system
    server.tool(
      'flutterSetThemeMode',
      description:
          'Switch between light and dark mode for testing. Useful for verifying UI appearance in both themes.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'mode': {
            'type': 'string',
            'description': 'Theme mode: light, dark, or system',
            'enum': ['light', 'dark', 'system'],
          },
        },
        required: ['instanceId', 'mode'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final mode = args['mode'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (mode == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: mode is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '🎨 [FlutterRuntimeServer] Setting theme mode to $mode for instance $instanceId',
          );

          await instance.setThemeMode(mode);

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Theme mode set to $mode. The app will now display with ${mode == "system" ? "system default" : mode} theme.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterSetThemeMode',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to set theme mode: $e'),
            ],
          );
        }
      },
    );

    // Flutter Get Theme Mode - Get current theme mode
    server.tool(
      'flutterGetThemeMode',
      description: 'Get the current theme mode (light, dark, or system).',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          final mode = await instance.getThemeMode();

          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Current theme mode: $mode'),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterGetThemeMode',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to get theme mode: $e'),
            ],
          );
        }
      },
    );

    // Flutter Set Locale - Change app locale for i18n testing
    server.tool(
      'flutterSetLocale',
      description:
          'Change the app locale for internationalization testing. Test RTL layouts, text overflow in different languages, etc.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
          'locale': {
            'type': 'string',
            'description':
                'Locale code in format "en-US", "ja-JP", "ar-SA", etc.',
          },
        },
        required: ['instanceId', 'locale'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;
        final locale = args['locale'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        if (locale == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: locale is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '🌍 [FlutterRuntimeServer] Setting locale to $locale for instance $instanceId',
          );

          await instance.setLocale(locale);

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Locale set to $locale. The app will now display with this locale if supported.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterSetLocale',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to set locale: $e'),
            ],
          );
        }
      },
    );

    // Flutter Reset Locale - Reset to system locale
    server.tool(
      'flutterResetLocale',
      description: 'Reset the locale to the system default.',
      toolInputSchema: ToolInputSchema(
        properties: {
          'instanceId': {
            'type': 'string',
            'description': 'UUID of the Flutter instance',
          },
        },
        required: ['instanceId'],
      ),
      callback: ({args, extra}) async {
        final instanceId = args!['instanceId'] as String?;

        if (instanceId == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: instanceId is required')],
          );
        }

        final instance = _instances[instanceId];
        if (instance == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Error: Flutter instance not found with ID: $instanceId',
              ),
            ],
          );
        }

        try {
          print(
            '🌍 [FlutterRuntimeServer] Resetting locale to system default for instance $instanceId',
          );

          await instance.resetLocale();

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text:
                    'Locale reset to system default. The app will now use the device locale.',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'flutterResetLocale',
            instanceId: instanceId,
          );
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Failed to reset locale: $e'),
            ],
          );
        }
      },
    );
  }

  /// Inject -t (target) flag into command to point to synthetic main
  /// Handles the case where -t flag might already be present
  List<String> _injectTargetFlag(List<String> command, String targetPath) {
    // Check if -t or --target flag is already present
    for (var i = 0; i < command.length; i++) {
      if (command[i] == '-t' || command[i] == '--target') {
        // Flag already present, don't add duplicate
        return command;
      }
    }

    final result = List<String>.from(command);

    // Find 'run' command and insert -t flag after it
    final runIndex = result.indexOf('run');
    if (runIndex != -1) {
      result.insert(runIndex + 1, '-t');
      result.insert(runIndex + 2, targetPath);
    }

    return result;
  }

  /// Parse command string into list of arguments
  /// Handles quoted strings properly
  List<String> _parseCommand(String command) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuotes) {
        inQuotes = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuotes) {
        inQuotes = false;
        quoteChar = '';
      } else if (char == ' ' && !inQuotes) {
        if (current.isNotEmpty) {
          result.add(current.toString());
          current = StringBuffer();
        }
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      result.add(current.toString());
    }

    return result;
  }

  /// Format elements list as compact text
  String _formatElements(Map<String, dynamic> result) {
    final elements = result['elements'] as List<dynamic>? ?? [];
    if (elements.isEmpty) {
      return '(no elements)';
    }

    final buffer = StringBuffer();
    for (final element in elements) {
      final id = element['id'] as String?;
      final type = element['type'] as String?;
      final label = element['label'] as String?;
      final enabled = element['enabled'];
      final checked = element['checked'];

      buffer.write('- $id ($type)');
      if (label != null && label.isNotEmpty) buffer.write(': "$label"');
      if (enabled == false) buffer.write(' [disabled]');
      if (checked != null) buffer.write(' [${checked ? '✓' : '○'}]');
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  /// Get a Flutter instance by ID for direct stream access
  /// Returns null if instance not found
  FlutterInstance? getInstance(String instanceId) {
    return _instances[instanceId];
  }

  /// Get all Flutter instances for direct stream access
  List<FlutterInstance> getAllInstances() {
    return _instances.values.toList();
  }

  /// Call the flutterAct logic directly (for TUI debugging tool)
  Future<String> callFlutterAct({
    FlutterInstance? instance,
    String? instanceId,
    required String action,
    required String description,
  }) async {
    if (action != 'click' && action != 'tap') {
      throw ArgumentError('action must be "click" or "tap"');
    }

    // Use provided instance or look up by ID
    final targetInstance = instance ?? _instances[instanceId];
    if (targetInstance == null) {
      throw ArgumentError('Flutter instance not found with ID: $instanceId');
    }

    if (_moondreamClient == null) {
      throw StateError(
        'Moondream API not available. Set MOONDREAM_API_KEY environment variable.',
      );
    }

    // Step 1: Take screenshot
    final screenshotBytes = await targetInstance.screenshot();
    if (screenshotBytes == null) {
      throw StateError('Failed to capture screenshot');
    }

    // Step 2: Encode screenshot for Moondream
    final imageUrl = ImageEncoder.encodeBytes(
      Uint8List.fromList(screenshotBytes),
      mimeType: 'image/png',
    );

    // Step 3: Use Moondream's point API to find the element coordinates
    final pointResponse = await _moondreamClient!
        .point(imageUrl: imageUrl, object: description)
        .timeout(
          _moondreamTimeout,
          onTimeout: () => throw TimeoutException(
            'Moondream point API timed out after ${_moondreamTimeout.inSeconds}s',
          ),
        );

    // Get normalized coordinates (0-1 range)
    final normalizedX = pointResponse.x;
    final normalizedY = pointResponse.y;

    // Validate coordinates
    if (normalizedX == null || normalizedY == null) {
      throw StateError(
        'Moondream could not find "$description" (no points returned)',
      );
    }

    if (normalizedX.isNaN ||
        normalizedY.isNaN ||
        normalizedX < 0 ||
        normalizedY < 0 ||
        normalizedX > 1 ||
        normalizedY > 1) {
      throw StateError(
        'Moondream returned invalid normalized coordinates: ($normalizedX, $normalizedY)',
      );
    }

    // Decode PNG to get dimensions
    final bytes = Uint8List.fromList(screenshotBytes);
    if (bytes.length < 24 ||
        bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) {
      throw StateError('Invalid PNG format from screenshot');
    }

    // Read width and height from PNG header (big-endian)
    final width =
        (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height =
        (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];

    print(
      '🖼️  [FlutterRuntimeServer] Screenshot dimensions: ${width}x$height',
    );
    print(
      '   Normalized coordinates from Moondream: ($normalizedX, $normalizedY)',
    );

    // Convert normalized coordinates to physical pixel coordinates
    final pixelRatioX = (normalizedX * width).round().toDouble();
    final pixelRatioY = (normalizedY * height).round().toDouble();

    print('   Physical pixel coordinates: ($pixelRatioX, $pixelRatioY)');

    // Divide by devicePixelRatio to get logical pixels
    // Use the instance's devicePixelRatio (from last screenshot) for accurate conversion
    final devicePixelRatio = targetInstance.devicePixelRatio;
    final x = (pixelRatioX / devicePixelRatio).round().toDouble();
    final y = (pixelRatioY / devicePixelRatio).round().toDouble();

    print('   Logical pixel coordinates (÷$devicePixelRatio): ($x, $y)');
    print('   🎯 CALLING instance.tap($x, $y)');

    // Step 4: Perform tap
    final success = await targetInstance.tap(x, y);

    if (success) {
      return 'Successfully performed $action on "$description" at coordinates ($x, $y)';
    } else {
      throw StateError('Tap command returned false');
    }
  }

  @override
  Future<void> onStop() async {
    // Stop all running instances with proper error handling
    final instanceIds = _instances.keys.toList();
    for (final instanceId in instanceIds) {
      try {
        final instance = _instances[instanceId];
        if (instance != null) {
          await instance.stop().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              // Instance stop timed out, continue with cleanup
            },
          );
        }
      } catch (e) {
        // Log but continue with other instances
        print('[FlutterRuntimeServer] Error stopping instance $instanceId: $e');
      }
    }
    _instances.clear();

    // Clean up all synthetic main files
    final workingDirs = _instanceWorkingDirs.values.toList();
    for (final workingDir in workingDirs) {
      try {
        await SyntheticMainGenerator.cleanup(workingDir);
      } catch (e) {
        // Log but continue with other cleanup
        print(
          '[FlutterRuntimeServer] Error cleaning up synthetic main in $workingDir: $e',
        );
      }
    }
    _instanceWorkingDirs.clear();

    // Dispose Moondream client
    try {
      _moondreamClient?.dispose();
    } catch (e) {
      // Moondream cleanup failed, ignore
    }
    _moondreamClient = null;
  }
}
