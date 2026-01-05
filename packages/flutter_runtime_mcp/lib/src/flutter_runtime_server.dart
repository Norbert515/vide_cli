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
      description: 'Take a screenshot of a running Flutter instance',
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
          'Perform an action on a Flutter UI element by describing it in natural language. Uses vision AI (Moondream) to locate the element. Returns a screenshot after the action.',
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
          final pointResponse = await _moondreamClient!.point(
            imageUrl: imageUrl,
            object: description,
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
            // Wait for UI to update before taking screenshot
            await Future.delayed(const Duration(milliseconds: 300));

            // Take screenshot to show the result
            final resultScreenshot = await instance.screenshot();

            final content = <Content>[
              TextContent(
                text:
                    'Successfully performed $action on "$description" at coordinates ($x, $y)',
              ),
            ];

            // Add screenshot if available
            if (resultScreenshot != null) {
              content.add(_createScreenshotContent(resultScreenshot));
            }

            return CallToolResult.fromContent(content: content);
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Tap command returned false')],
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
            // Wait for UI to update before taking screenshot
            await Future.delayed(const Duration(milliseconds: 300));

            // Take screenshot to show the result
            final resultScreenshot = await instance.screenshot();

            final content = <Content>[
              TextContent(
                text:
                    'Successfully performed tap at coordinates ($x, $y) [from normalized ($coordinateX, $coordinateY)]',
              ),
            ];

            // Add screenshot if available
            if (resultScreenshot != null) {
              content.add(_createScreenshotContent(resultScreenshot));
            }

            return CallToolResult.fromContent(content: content);
          } else {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Error: Tap command returned false')],
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
            // Wait for UI to update before taking screenshot
            await Future.delayed(const Duration(milliseconds: 300));

            // Take screenshot to show the result
            final resultScreenshot = await instance.screenshot();

            final content = <Content>[
              TextContent(text: 'Successfully typed text: "$text"'),
            ];

            // Add screenshot if available
            if (resultScreenshot != null) {
              content.add(_createScreenshotContent(resultScreenshot));
            }

            return CallToolResult.fromContent(content: content);
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Type command returned false'),
              ],
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
          final queryResponse = await _moondreamClient!.query(
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
            // Wait for UI to update and animations to complete
            await Future.delayed(const Duration(milliseconds: 500));

            // Take screenshot to show the result
            final resultScreenshot = await instance.screenshot();

            final content = <Content>[
              TextContent(
                text:
                    'Successfully performed scroll: "$instruction" at ($startX, $startY) with delta ($dx, $dy)',
              ),
            ];

            // Add screenshot if available
            if (resultScreenshot != null) {
              content.add(_createScreenshotContent(resultScreenshot));
            }

            return CallToolResult.fromContent(content: content);
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Scroll command returned false'),
              ],
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
            // Wait for UI to update and animations to complete
            await Future.delayed(const Duration(milliseconds: 500));

            // Take screenshot to show the result
            final resultScreenshot = await instance.screenshot();

            final content = <Content>[
              TextContent(
                text:
                    'Successfully performed scroll at ($startX, $startY) with delta ($dx, $dy) [from normalized start=($normalizedStartX, $normalizedStartY), delta=($normalizedDx, $normalizedDy)]',
              ),
            ];

            // Add screenshot if available
            if (resultScreenshot != null) {
              content.add(_createScreenshotContent(resultScreenshot));
            }

            return CallToolResult.fromContent(content: content);
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Scroll command returned false'),
              ],
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
    final pointResponse = await _moondreamClient!.point(
      imageUrl: imageUrl,
      object: description,
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
    // Stop all running instances
    for (final instance in _instances.values) {
      await instance.stop();
    }
    _instances.clear();

    // Clean up all synthetic main files
    for (final workingDir in _instanceWorkingDirs.values) {
      await SyntheticMainGenerator.cleanup(workingDir);
    }
    _instanceWorkingDirs.clear();

    // Dispose Moondream client
    _moondreamClient?.dispose();
  }
}
