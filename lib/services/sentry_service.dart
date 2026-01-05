import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';
import 'package:sentry/sentry.dart';

class SentryService {
  static const String _dsn =
      'https://72bde1285798c1a0ec98c770c65cad3a@o4510511934275584.ingest.de.sentry.io/4510511935717456';

  static bool _initialized = false;

  /// Initialize Sentry and set up nocterm error handler.
  /// Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;

    await Sentry.init((options) {
      options.dsn = _dsn;
      options.tracesSampleRate = 1.0;
      options.environment = const String.fromEnvironment(
        'SENTRY_ENV',
        defaultValue: 'development',
      );
    });

    // Set up nocterm's global error handler (like Flutter's FlutterError.onError)
    NoctermError.onError = (details) {
      // Report to Sentry
      Sentry.captureException(details.exception, stackTrace: details.stack);
      PostHogService.errorOccurred(details.exception.runtimeType.toString());
      // Still log to console
      NoctermError.dumpErrorToConsole(details);
    };

    _initialized = true;
  }

  /// Capture an exception manually
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
  }) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
    PostHogService.errorOccurred(exception.runtimeType.toString());
  }
}
