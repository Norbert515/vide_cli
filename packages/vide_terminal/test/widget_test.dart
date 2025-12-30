import 'package:flutter_test/flutter_test.dart';

import 'package:vide_terminal/main.dart';

void main() {
  testWidgets('VideTerminalApp can be instantiated', (WidgetTester tester) async {
    await tester.pumpWidget(const VideTerminalApp());
    // The app should build without errors
    expect(find.byType(VideTerminalApp), findsOneWidget);
  });
}
