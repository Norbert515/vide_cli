import '../../../../../utils/system_prompt_builder.dart';

/// Section explaining the automatic runtime AI dev tools injection.
/// The setup is now fully automated via synthetic main generation.
class RuntimeDevToolsSetupSection extends PromptSection {
  @override
  String build() {
    return '''
### Runtime AI Dev Tools

The runtime AI dev tools are **automatically injected** when you start a Flutter app using the `flutterStart` tool. No manual setup is required.

**What happens automatically:**
1. A synthetic main file is generated in `.dart_tool/vide_debug_main.dart`
2. Your app is wrapped with a debug overlay for tap visualization
3. Service extensions are registered for: screenshots, taps, typing, and scrolling
4. The app is launched using `flutter run --target` pointing to the synthetic main

**Important:** The project must have `runtime_ai_dev_tools` as a dependency in `pubspec.yaml`.
''';
  }
}
