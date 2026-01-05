import 'package:vm_service/vm_service.dart' as vms;

/// Utility class for evaluating Dart expressions via VM Service
///
/// This class handles the complexity of VM Service evaluation, including
/// isolate and library management, error handling, and common Flutter API calls.
class VmServiceEvaluator {
  final vms.VmService vmService;
  final String isolateId;
  final String rootLibraryId;

  // Track overlay inspector IDs for cleanup
  final Map<String, String> _overlayInspectorIds = {};

  VmServiceEvaluator({
    required this.vmService,
    required this.isolateId,
    required this.rootLibraryId,
  });

  /// Create an evaluator from a VM Service connection
  ///
  /// This discovers the isolate and root library automatically.
  static Future<VmServiceEvaluator?> create(vms.VmService vmService) async {
    try {
      final vm = await vmService.getVM();
      if (vm.isolates == null || vm.isolates!.isEmpty) {
        return null;
      }

      final isolateId = vm.isolates!.first.id!;
      final isolate = await vmService.getIsolate(isolateId);

      if (isolate.rootLib == null) {
        return null;
      }

      return VmServiceEvaluator(
        vmService: vmService,
        isolateId: isolateId,
        rootLibraryId: isolate.rootLib!.id!,
      );
    } catch (e) {
      return null;
    }
  }

  /// Evaluate a Dart expression in the root library context
  ///
  /// Returns the result as an InstanceRef, ErrorRef, or Sentinel.
  /// Throws VmServiceEvaluationException on errors.
  Future<vms.Response> evaluate(
    String expression, {
    Map<String, String>? scope,
    bool disableBreakpoints = true,
  }) async {
    try {
      final result = await vmService.evaluate(
        isolateId,
        rootLibraryId,
        expression,
        scope: scope,
        disableBreakpoints: disableBreakpoints,
      );
      return result;
    } on vms.SentinelException catch (e) {
      throw VmServiceEvaluationException(
        'Object collected or expired during evaluation',
        originalError: e,
      );
    } on vms.RPCError catch (e) {
      if (e.code == 113) {
        throw VmServiceEvaluationException(
          'Expression compilation error: ${e.message}',
          originalError: e,
          isCompilationError: true,
        );
      }
      throw VmServiceEvaluationException(
        'RPC error (code ${e.code}): ${e.message}',
        originalError: e,
      );
    }
  }

  /// Show a visual cursor at the given coordinates
  ///
  /// This creates a semi-transparent circle overlay that fades out after a duration.
  /// Uses WidgetInspectorService to prevent garbage collection.
  /// Works without any modifications to the target app.
  Future<void> showCursor({
    required double x,
    required double y,
    Duration duration = const Duration(milliseconds: 1000),
    String color = '0x80FF0000', // Semi-transparent red
    double radius = 25,
  }) async {
    // Disabled for now - widget classes not available in evaluation context
    // The issue is that OverlayEntry, Positioned, etc. aren't in scope
    // even though the app uses MaterialApp. This would require adding
    // explicit imports to the target app, which defeats the purpose.
    //
    // TODO: Investigate using a service extension instead for cursor visualization
    return;
  }

  /// Remove a specific cursor overlay
  Future<void> hideCursor(double x, double y) async {
    final key = '$x-$y';
    final inspectorId = _overlayInspectorIds.remove(key);

    if (inspectorId == null) return;

    try {
      await evaluate(
        '''
() {
  final entry = WidgetInspectorService.instance.toObject(id, 'tap-cursors');
  entry?.remove();
  WidgetInspectorService.instance.disposeId(id, 'tap-cursors');
}()
        ''',
        scope: {'id': inspectorId},
      );
    } catch (e) {
      throw VmServiceEvaluationException(
        'Failed to hide cursor overlay at ($x, $y): $e',
        originalError: e,
      );
    }
  }

  /// Remove all cursor overlays and clean up resources
  Future<void> dispose() async {
    try {
      // Dispose entire overlay group
      await evaluate(
        'WidgetInspectorService.instance.disposeGroup("tap-cursors")',
      );

      _overlayInspectorIds.clear();
    } catch (e) {
      throw VmServiceEvaluationException(
        'Failed to dispose cursor overlays: $e',
        originalError: e,
      );
    }
  }

  /// Simulate a tap at the given coordinates by dispatching pointer events
  ///
  /// This dispatches PointerDownEvent and PointerUpEvent to Flutter's
  /// GestureBinding with a realistic delay between them.
  ///
  /// This works without requiring any imports in the target app - it uses
  /// WidgetsFlutterBinding which is automatically available in Flutter apps.
  Future<void> tap(
    double x,
    double y, {
    Duration? delay,
    bool showCursor = true,
  }) async {
    final tapDelay = delay ?? const Duration(milliseconds: 100);

    // Show cursor visualization if enabled
    if (showCursor) {
      await this.showCursor(x: x, y: y);
    }

    // Use WidgetsFlutterBinding which is always available in Flutter apps
    // and includes all the necessary gesture handling
    await evaluate(
      'WidgetsFlutterBinding.ensureInitialized().handlePointerEvent('
      'PointerDownEvent(position: Offset($x, $y))'
      ')',
    );

    // Wait for realistic tap duration
    await Future.delayed(tapDelay);

    // Dispatch pointer up event
    await evaluate(
      'WidgetsFlutterBinding.ensureInitialized().handlePointerEvent('
      'PointerUpEvent(position: Offset($x, $y))'
      ')',
    );
  }

  /// Simulate a long press at the given coordinates
  Future<void> longPress(
    double x,
    double y, {
    Duration? duration,
    bool showCursor = true,
  }) async {
    final pressDuration = duration ?? const Duration(milliseconds: 500);

    // Show cursor visualization if enabled
    if (showCursor) {
      await this.showCursor(
        x: x,
        y: y,
        duration: pressDuration + const Duration(milliseconds: 500),
      );
    }

    await evaluate(
      'GestureBinding.instance.handlePointerEvent('
      'PointerDownEvent(position: Offset($x, $y))'
      ')',
    );

    await Future.delayed(pressDuration);

    await evaluate(
      'GestureBinding.instance.handlePointerEvent('
      'PointerUpEvent(position: Offset($x, $y))'
      ')',
    );
  }

  /// Simulate a drag gesture from one point to another
  Future<void> drag(
    double startX,
    double startY,
    double endX,
    double endY, {
    int steps = 10,
    Duration? duration,
    bool showCursor = true,
  }) async {
    final totalDuration = duration ?? const Duration(milliseconds: 300);
    final stepDelay = Duration(
      milliseconds: totalDuration.inMilliseconds ~/ steps,
    );

    // Show cursor at start position if enabled
    if (showCursor) {
      await this.showCursor(
        x: startX,
        y: startY,
        duration: totalDuration + const Duration(milliseconds: 500),
      );
    }

    // Pointer down
    await evaluate(
      'GestureBinding.instance.handlePointerEvent('
      'PointerDownEvent(position: Offset($startX, $startY))'
      ')',
    );

    // Move in steps
    for (var i = 1; i <= steps; i++) {
      final progress = i / steps;
      final x = startX + (endX - startX) * progress;
      final y = startY + (endY - startY) * progress;

      await Future.delayed(stepDelay);

      await evaluate(
        'GestureBinding.instance.handlePointerEvent('
        'PointerMoveEvent(position: Offset($x, $y))'
        ')',
      );
    }

    // Pointer up
    await evaluate(
      'GestureBinding.instance.handlePointerEvent('
      'PointerUpEvent(position: Offset($endX, $endY))'
      ')',
    );
  }

  /// Diagnostic method to test what classes are available in the evaluation context
  ///
  /// This helps debug why certain Flutter widgets/classes fail to evaluate.
  /// Returns a map of class name to availability (true if accessible, false if not).
  Future<Map<String, bool>> diagnoseAvailableClasses() async {
    final tests = <String, bool>{};

    // Test basic Flutter classes
    final classesToTest = [
      'WidgetsBinding',
      'WidgetsFlutterBinding',
      'WidgetInspectorService',
      'GestureBinding',
      'Overlay',
      'OverlayEntry',
      'OverlayState',
      'Positioned',
      'Container',
      'IgnorePointer',
      'BoxDecoration',
      'Color',
      'Colors',
      'Border',
      'BorderSide',
      'BoxShape',
      'Offset',
      'Duration',
      'Future',
      'BuildContext',
      'StatelessWidget',
      'StatefulWidget',
      'Widget',
      'MaterialApp',
      'Scaffold',
      'PointerDownEvent',
      'PointerUpEvent',
      'PointerMoveEvent',
    ];

    for (final className in classesToTest) {
      try {
        await evaluate('$className.toString()');
        tests[className] = true;
      } catch (e) {
        tests[className] = false;
      }
    }

    return tests;
  }

  /// Test overlay creation step by step to find where it fails
  ///
  /// This progressively tests each step of creating a cursor overlay
  /// to identify exactly where compilation or runtime errors occur.
  /// Returns a map with test names as keys and results as values.
  Future<Map<String, String>> testOverlayCreation(double x, double y) async {
    final results = <String, String>{};

    // Test 1: Can we access WidgetsBinding.instance?
    try {
      await evaluate('WidgetsBinding.instance.toString()');
      results['WidgetsBinding.instance'] = 'SUCCESS';
    } catch (e) {
      results['WidgetsBinding.instance'] = 'FAIL: $e';
      return results;
    }

    // Test 2: Can we access rootElement?
    try {
      await evaluate('WidgetsBinding.instance.rootElement.toString()');
      results['rootElement'] = 'SUCCESS';
    } catch (e) {
      results['rootElement'] = 'FAIL: $e';
      return results;
    }

    // Test 3: Can we get Overlay?
    try {
      await evaluate(
        'Overlay.of(WidgetsBinding.instance.rootElement!).toString()',
      );
      results['Overlay.of'] = 'SUCCESS';
    } catch (e) {
      results['Overlay.of'] = 'FAIL: $e';
      return results;
    }

    // Test 4: Can we create OverlayEntry with minimal widget?
    try {
      await evaluate('''
OverlayEntry(
  builder: (context) => Container()
).toString()
''');
      results['OverlayEntry creation'] = 'SUCCESS';
    } catch (e) {
      results['OverlayEntry creation'] = 'FAIL: $e';
      return results;
    }

    // Test 5: Can we create with Positioned?
    try {
      await evaluate('''
OverlayEntry(
  builder: (context) => Positioned(
    left: $x,
    top: $y,
    child: Container(),
  )
).toString()
''');
      results['Positioned widget'] = 'SUCCESS';
    } catch (e) {
      results['Positioned widget'] = 'FAIL: $e';
      return results;
    }

    // Test 6: Full overlay creation (no insert)
    try {
      await evaluate('''
() {
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: $x,
      top: $y,
      child: Container(
        width: 50,
        height: 50,
        color: Color(0xFFFF0000),
      ),
    ),
  );
  return entry.toString();
}()
''');
      results['Full overlay creation'] = 'SUCCESS';
    } catch (e) {
      results['Full overlay creation'] = 'FAIL: $e';
      return results;
    }

    // Test 7: Test with decoration
    try {
      await evaluate('''
() {
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: $x,
      top: $y,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Color(0x80FF0000),
          shape: BoxShape.circle,
          border: Border.all(
            color: Color(0xFFFFFFFF),
            width: 2,
          ),
        ),
      ),
    ),
  );
  return entry.toString();
}()
''');
      results['Full decoration'] = 'SUCCESS';
    } catch (e) {
      results['Full decoration'] = 'FAIL: $e';
      return results;
    }

    // Test 8: Try to insert into overlay
    try {
      await evaluate('''
() {
  final overlay = Overlay.of(WidgetsBinding.instance.rootElement!);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: $x,
      top: $y,
      child: Container(
        width: 50,
        height: 50,
        color: Color(0xFFFF0000),
      ),
    ),
  );
  overlay.insert(entry);
  return 'Inserted';
}()
''');
      results['Insert overlay'] = 'SUCCESS';
    } catch (e) {
      results['Insert overlay'] = 'FAIL: $e';
      return results;
    }

    return results;
  }

  /// Test alternative approaches to cursor visualization
  ///
  /// Since widget classes may not be available, test service extensions
  /// and other approaches.
  Future<Map<String, String>> testAlternativeApproaches(
    double x,
    double y,
  ) async {
    final results = <String, String>{};

    // Test 1: Can we use debugPaint?
    try {
      await evaluate('''
() {
  debugPaintSizeEnabled = true;
  return 'debugPaint enabled';
}()
''');
      results['debugPaint'] = 'SUCCESS';
    } catch (e) {
      results['debugPaint'] = 'FAIL: $e';
    }

    // Test 2: Can we access RenderView?
    try {
      await evaluate('''
WidgetsBinding.instance.renderViewElement?.renderObject.toString() ?? 'null'
''');
      results['RenderView access'] = 'SUCCESS';
    } catch (e) {
      results['RenderView access'] = 'FAIL: $e';
    }

    // Test 3: Can we schedule a frame?
    try {
      await evaluate('''
() {
  WidgetsBinding.instance.scheduleFrame();
  return 'Frame scheduled';
}()
''');
      results['Schedule frame'] = 'SUCCESS';
    } catch (e) {
      results['Schedule frame'] = 'FAIL: $e';
    }

    return results;
  }
}

/// Exception thrown when VM Service evaluation fails
class VmServiceEvaluationException implements Exception {
  final String message;
  final Object? originalError;
  final bool isCompilationError;

  VmServiceEvaluationException(
    this.message, {
    this.originalError,
    this.isCompilationError = false,
  });

  @override
  String toString() => 'VmServiceEvaluationException: $message';
}
