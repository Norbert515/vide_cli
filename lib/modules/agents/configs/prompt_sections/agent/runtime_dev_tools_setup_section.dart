import '../../../../../utils/system_prompt_builder.dart';

/// Temporary section for runtime_ai_dev_tools setup instructions.
/// This can be removed once the setup process is automated or no longer needed.
class RuntimeDevToolsSetupSection extends PromptSection {
  @override
  String build() {
    return '''
### Runtime AI Dev Tools Setup (REQUIRED)

**BEFORE running any Flutter app for testing, you MUST set up `runtime_ai_dev_tools`.**

This package provides the service extensions needed for screenshots and tap simulation.

#### Step 1: Check/Add Dependency

Check the app's `pubspec.yaml` for the `runtime_ai_dev_tools` dependency:

```yaml
dependencies:
  runtime_ai_dev_tools:
    path: /Users/norbertkozsir/IdeaProjects/parott/packages/runtime_ai_dev_tools
```

If missing:
1. Add it under `dependencies` in `pubspec.yaml`
2. Run `flutter pub get` (or `fvm flutter pub get` for FVM projects)

#### Step 2: Modify main.dart to Use runDebugApp

Find the app's `main.dart` file and locate the `runApp()` call. Replace it with `runDebugApp()`:

**Before:**
```dart
void main() {
  runApp(const MyApp());
}
```

**After:**
```dart
import 'package:runtime_ai_dev_tools/runtime_ai_dev_tools.dart';

void main() {
  runDebugApp(const MyApp());
}
```

**Important patterns to handle:**
- `runApp(MyApp())` → `runDebugApp(MyApp())`
- `runApp(const MyApp())` → `runDebugApp(const MyApp())`
- If there's `WidgetsFlutterBinding.ensureInitialized()` before `runApp`, keep it

#### Step 3: Track Changes for Revert

**CRITICAL:** You MUST track what you changed so you can revert later!

Use memory to store original state:
```
memorySave(key: "original_main_dart", value: "[original content or description]")
memorySave(key: "added_runtime_dep", value: "true/false")
```

#### Step 4: AFTER Testing - REVERT ALL CHANGES

**CRITICAL:** When testing is finished, you MUST revert all changes:

1. **Revert `main.dart`:** Change `runDebugApp()` back to `runApp()` and remove the import
2. **Remove dependency:** Remove `runtime_ai_dev_tools` from `pubspec.yaml` if it wasn't there before
3. **Run pub get:** Ensure dependencies are synced

**Quick Checklist:**
- [ ] Check if `runtime_ai_dev_tools` dependency exists in pubspec.yaml
- [ ] Add dependency if missing (path: `/Users/norbertkozsir/IdeaProjects/parott/packages/runtime_ai_dev_tools`)
- [ ] Run `flutter pub get` / `fvm flutter pub get`
- [ ] Find `runApp()` in `main.dart`
- [ ] Add import: `import 'package:runtime_ai_dev_tools/runtime_ai_dev_tools.dart';`
- [ ] Replace `runApp(...)` with `runDebugApp(...)`
- [ ] Save original state to memory for revert
- [ ] **After testing:** Revert `main.dart` changes
- [ ] **After testing:** Remove dependency if it wasn't there originally
- [ ] **After testing:** Run pub get to sync
''';
  }
}
