import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vide_mobile/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: VideApp(),
      ),
    );

    // Verify that the app launches with the connection screen.
    expect(find.text('Vide'), findsOneWidget);
    expect(find.text('Connect to Vide Server'), findsOneWidget);
  });
}
