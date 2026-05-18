import 'dart:async';
import 'dart:math';

/// Configuration for exponential backoff reconnection.
class ReconnectionConfig {
  /// Base delay between reconnection attempts.
  final Duration baseDelay;

  /// Maximum delay between reconnection attempts.
  final Duration maxDelay;

  /// Maximum number of retry attempts before giving up.
  final int maxRetries;

  /// Maximum jitter percentage (0.0 to 1.0) to add randomness to delays.
  final double maxJitter;

  const ReconnectionConfig({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.maxRetries = 5,
    this.maxJitter = 0.25,
  });
}

/// Service for managing reconnection with exponential backoff.
class ReconnectionService {
  final ReconnectionConfig config;
  final Random _random = Random();

  int _retryCount = 0;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  ReconnectionService({this.config = const ReconnectionConfig()});

  /// Current retry count.
  int get retryCount => _retryCount;

  /// Maximum retries allowed.
  int get maxRetries => config.maxRetries;

  /// Whether we're currently in a reconnection attempt.
  bool get isReconnecting => _isReconnecting;

  /// Whether we've exceeded the max retry count.
  bool get hasExceededMaxRetries => _retryCount >= config.maxRetries;

  /// Calculates the delay for the next reconnection attempt using
  /// exponential backoff with jitter.
  Duration calculateDelay() {
    // Exponential backoff: baseDelay * 2^retryCount
    final exponentialMs =
        config.baseDelay.inMilliseconds * pow(2, _retryCount).toInt();

    // Cap at max delay
    final cappedMs = min(exponentialMs, config.maxDelay.inMilliseconds);

    // Add jitter: random value between 0 and maxJitter * cappedMs
    final jitterMs =
        (_random.nextDouble() * config.maxJitter * cappedMs).toInt();

    return Duration(milliseconds: cappedMs + jitterMs);
  }

  /// Schedules a reconnection attempt.
  ///
  /// Returns a Future that completes when the delay has passed.
  /// Returns null if max retries exceeded.
  Future<void>? scheduleReconnect(
      {required Future<void> Function() onReconnect}) {
    if (hasExceededMaxRetries) {
      return null;
    }

    _isReconnecting = true;
    final delay = calculateDelay();
    _retryCount++;

    final completer = Completer<void>();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      try {
        await onReconnect();
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Resets the retry count. Call this on successful reconnection.
  void reset() {
    _retryCount = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Cancels any pending reconnection attempt.
  void cancel() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
  }

  /// Disposes of resources.
  void dispose() {
    cancel();
  }
}
