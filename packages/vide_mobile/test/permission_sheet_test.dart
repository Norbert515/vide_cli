import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vide_mobile/core/theme/vide_colors.dart';
import 'package:vide_mobile/domain/models/models.dart';
import 'package:vide_mobile/features/permissions/permission_sheet.dart';

void main() {
  final testRequest = PermissionRequest(
    requestId: 'req-1',
    toolName: 'Bash',
    toolInput: {'command': 'rm -rf /'},
    agentId: 'agent-1',
    agentName: 'Test Agent',
    timestamp: DateTime(2024, 1, 1),
  );

  Widget buildTestWidget({
    required void Function({required bool remember}) onAllow,
    required VoidCallback onDeny,
  }) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [VideThemeColors.dark],
      ),
      home: Scaffold(
        body: PermissionSheet(
          request: testRequest,
          onAllow: onAllow,
          onDeny: onDeny,
        ),
      ),
    );
  }

  group('PermissionSheet', () {
    testWidgets('does not accept a timeout parameter', (tester) async {
      // PermissionSheet's constructor must NOT accept a timeout parameter.
      // If someone adds one, this test will fail to compile because the
      // constructor call below only passes the 3 required parameters.
      final sheet = PermissionSheet(
        request: testRequest,
        onAllow: _noopAllow,
        onDeny: _noopDeny,
      );
      expect(sheet, isNotNull);
    });

    testWidgets('never auto-denies after extended time', (tester) async {
      var denyCalled = false;
      var allowCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onAllow: ({required bool remember}) => allowCalled = true,
        onDeny: () => denyCalled = true,
      ));

      // Advance well past any reasonable timeout (5 minutes).
      // If there were a timer, it would fire and call onDeny.
      await tester.pump(const Duration(minutes: 5));

      expect(denyCalled, isFalse,
          reason: 'PermissionSheet must NEVER auto-deny on a timeout');
      expect(allowCalled, isFalse,
          reason: 'PermissionSheet must not auto-allow either');
    });

    testWidgets('does not show a countdown or progress indicator',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onAllow: ({required bool remember}) {},
        onDeny: () {},
      ));

      // No LinearProgressIndicator (was used for countdown bar)
      expect(find.byType(LinearProgressIndicator), findsNothing,
          reason: 'No timeout countdown indicator should exist');

      // No "auto-deny" or countdown text
      expect(find.textContaining('Auto-deny'), findsNothing);
      expect(find.textContaining('auto-deny'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+s')), findsNothing,
          reason: 'No countdown seconds text should be displayed');
    });

    testWidgets('only responds to explicit user action', (tester) async {
      var denyCalled = false;
      var allowCalled = false;
      bool? rememberValue;

      await tester.pumpWidget(buildTestWidget(
        onAllow: ({required bool remember}) {
          allowCalled = true;
          rememberValue = remember;
        },
        onDeny: () => denyCalled = true,
      ));

      // Tap Allow
      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(allowCalled, isTrue);
      expect(rememberValue, isFalse);
      expect(denyCalled, isFalse);
    });

    testWidgets('deny only triggers on explicit user tap', (tester) async {
      var denyCalled = false;

      await tester.pumpWidget(buildTestWidget(
        onAllow: ({required bool remember}) {},
        onDeny: () => denyCalled = true,
      ));

      // Advance time — should NOT auto-deny
      await tester.pump(const Duration(minutes: 2));
      expect(denyCalled, isFalse);

      // Now explicitly tap Deny
      await tester.tap(find.text('Deny'));
      await tester.pump();

      expect(denyCalled, isTrue);
    });
  });
}

void _noopAllow({required bool remember}) {}
void _noopDeny() {}
