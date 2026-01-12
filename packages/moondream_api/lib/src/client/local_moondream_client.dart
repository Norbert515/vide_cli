import 'dart:io';

import 'package:http/http.dart' as http;

import '../exceptions/moondream_exception.dart';
import '../models/config.dart';
import 'moondream_client.dart';

/// Default port for Moondream Station local server
const int defaultMoondreamPort = 2020;

/// Default host for Moondream Station local server
const String defaultMoondreamHost = 'localhost';

/// Client for interacting with a local Moondream Station server.
///
/// Moondream Station runs locally and provides the same REST API as the cloud
/// service but without authentication requirements.
///
/// Example usage:
/// ```dart
/// // Connect to default localhost:2020
/// final client = LocalMoondreamClient();
///
/// // Connect to custom host/port
/// final client = LocalMoondreamClient.custom(host: '192.168.1.100', port: 3000);
///
/// // Check if server is available
/// final available = await client.isAvailable();
/// if (available) {
///   final response = await client.query(
///     imageUrl: 'data:image/png;base64,...',
///     question: 'What is in this image?',
///   );
/// }
/// ```
class LocalMoondreamClient extends MoondreamClient {
  /// Create a client connected to the default local Moondream Station.
  ///
  /// Connects to `http://localhost:2020/v1` with a 90 second timeout
  /// (longer than cloud to account for local hardware variance).
  LocalMoondreamClient({http.Client? httpClient})
      : super(
          config: _localConfig(),
          httpClient: httpClient,
        );

  /// Create a client connected to a custom local Moondream Station.
  ///
  /// [host] - The hostname or IP address of the Moondream Station server
  /// [port] - The port number (defaults to 2020)
  /// [timeout] - Request timeout (defaults to 90 seconds)
  /// [verbose] - Enable verbose logging for debugging
  LocalMoondreamClient.custom({
    String host = defaultMoondreamHost,
    int port = defaultMoondreamPort,
    Duration timeout = const Duration(seconds: 90),
    bool verbose = false,
    http.Client? httpClient,
  }) : super(
          config: MoondreamConfig(
            baseUrl: 'http://$host:$port/v1',
            apiKey: null,
            timeout: timeout,
            retryAttempts: 2,
            retryDelay: const Duration(seconds: 2),
            verbose: verbose,
          ),
          httpClient: httpClient,
        );

  /// Create default config for local Moondream Station
  static MoondreamConfig _localConfig() {
    return const MoondreamConfig(
      baseUrl: 'http://localhost:2020/v1',
      apiKey: null,
      timeout: Duration(seconds: 90),
      retryAttempts: 2,
      retryDelay: Duration(seconds: 2),
    );
  }

  /// Check if the local Moondream Station server is available.
  ///
  /// Attempts to connect to the server with a short timeout.
  /// Returns `true` if the server responds, `false` otherwise.
  ///
  /// This is useful for checking server availability before making
  /// actual inference requests.
  Future<bool> isAvailable({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final url = Uri.parse(config.baseUrl.replaceAll('/v1', '/health'));
      final response = await http.get(url).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// The base URL of the local Moondream Station server.
  String get baseUrl => config.baseUrl;

  /// Create a client that automatically starts Moondream Station if not running.
  ///
  /// This factory will:
  /// 1. Check if the server is already running
  /// 2. If not, find and start the `moondream-station` executable
  /// 3. Wait for the server to become available
  /// 4. Return the connected client
  ///
  /// Throws [MoondreamServerStartException] if the server cannot be started.
  static Future<LocalMoondreamClient> withAutoStart({
    http.Client? httpClient,
  }) async {
    await ensureServerRunning();
    return LocalMoondreamClient(httpClient: httpClient);
  }

  /// Ensure the Moondream Station server is running.
  ///
  /// Checks if the server is already available. If not, attempts to find
  /// and start the `moondream-station` executable.
  ///
  /// Returns `true` if the server is now running.
  ///
  /// Throws [MoondreamServerStartException] if:
  /// - The `moondream-station` executable cannot be found
  /// - The server fails to start within the timeout period
  static Future<bool> ensureServerRunning({
    Duration pollInterval = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Check if server is already running
    if (await _isServerHealthy()) {
      return true;
    }

    // Find the moondream-station executable
    final executablePath = await _findMoondreamExecutable();
    if (executablePath == null) {
      throw const MoondreamServerStartException(
        message: 'Could not find moondream-station executable. '
            'Please ensure Moondream Station is installed and available in PATH '
            'or at ~/.local/bin/moondream-station',
      );
    }

    // Start the server
    await _startServer(executablePath);

    // Wait for server to become available
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (await _isServerHealthy()) {
        return true;
      }
      await Future.delayed(pollInterval);
    }

    throw MoondreamServerStartException(
      message: 'Moondream Station started but failed to become healthy '
          'within ${timeout.inSeconds} seconds',
    );
  }

  /// Check if the server health endpoint responds successfully.
  static Future<bool> _isServerHealthy() async {
    try {
      final url = Uri.parse('http://$defaultMoondreamHost:$defaultMoondreamPort/health');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Find the moondream-station executable.
  ///
  /// Checks:
  /// 1. `which moondream-station` (PATH lookup)
  /// 2. `~/.local/bin/moondream-station` (common install location)
  static Future<String?> _findMoondreamExecutable() async {
    // Try `which` first (works on macOS and Linux)
    try {
      final result = await Process.run('which', ['moondream-station']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          return path;
        }
      }
    } catch (_) {
      // which command failed, continue to fallback
    }

    // Check common installation location
    final homeDir = Platform.environment['HOME'];
    if (homeDir != null) {
      final localBinPath = '$homeDir/.local/bin/moondream-station';
      if (await File(localBinPath).exists()) {
        return localBinPath;
      }
    }

    return null;
  }

  /// Start the Moondream Station server.
  ///
  /// Uses a shell to pipe "start" to the interactive moondream-station command.
  /// The process is started in detached mode so it continues running after
  /// the Dart process exits.
  static Future<void> _startServer(String executablePath) async {
    // Use shell to pipe "start" command to moondream-station
    // The & at the end backgrounds the process
    await Process.start(
      '/bin/sh',
      ['-c', 'echo "start" | "$executablePath" &'],
      mode: ProcessStartMode.detached,
      environment: Platform.environment,
    );

    // Give the process a moment to start before we begin polling
    await Future.delayed(const Duration(seconds: 1));
  }
}
