# Flutter Runtime MCP Logging Guide

## Overview

The `flutter_runtime_mcp` package now includes comprehensive logging to help debug service extension calls, understand the flow of operations, and diagnose issues with screenshots and taps.

## Logging Locations

### FlutterInstance Methods

Both `screenshot()` and `tap()` methods in `lib/src/flutter_instance.dart` now include detailed logging.

## Log Symbols and Meanings

| Symbol | Meaning | Description |
|--------|---------|-------------|
| 🔍 | Investigation | Method entry point |
| ✅ | Success | Operation completed successfully |
| ❌ | Error | Fatal error occurred |
| ⚠️ | Warning | Non-fatal issue, fallback in progress |
| 🔧 | Tool/Action | Calling a service extension or API |
| 📥 | Response | Received response from service |
| ⏱️ | Timing | Delay or wait operation |

## Screenshot Logging

### Example Output

```
🔍 [FlutterInstance] screenshot() called for instance abc-123
⏱️  [FlutterInstance] Waiting 500ms before screenshot...
🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.screenshot
📥 [FlutterInstance] Received response from runtime_ai_dev_tools
   Response type: Success
   Response JSON keys: [status, image]
✅ [FlutterInstance] runtime_ai_dev_tools screenshot successful
✅ [FlutterInstance] Screenshot decoded: 245678 bytes
```

### What the Logs Tell You

**Step 1: Method Called**
```
🔍 [FlutterInstance] screenshot() called for instance abc-123
```
- Confirms the method was invoked
- Shows which instance ID is being used

**Step 2: VM Service Check**
```
⚠️  [FlutterInstance] VM Service not connected, attempting to connect...
✅ [FlutterInstance] VM Service connected
```
- Only appears if VM Service wasn't already connected
- Shows connection attempt and result

**Step 3: Delay**
```
⏱️  [FlutterInstance] Waiting 500ms before screenshot...
```
- Recommended delay to ensure UI is stable
- Helps with rendering consistency

**Step 4: runtime_ai_dev_tools Extension Attempt**
```
🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.screenshot
📥 [FlutterInstance] Received response from runtime_ai_dev_tools
   Response type: Success
   Response JSON keys: [status, image]
```
- First tries the enhanced extension
- Shows response type and available JSON keys
- If successful, proceeds to decode

**Step 5: Success or Fallback**
```
✅ [FlutterInstance] runtime_ai_dev_tools screenshot successful
✅ [FlutterInstance] Screenshot decoded: 245678 bytes
```
OR (if runtime_ai_dev_tools not available):
```
⚠️  [FlutterInstance] runtime_ai_dev_tools extension not available: RPCError(...)
   Falling back to built-in _flutter.screenshot extension
🔧 [FlutterInstance] Attempting to call _flutter.screenshot (fallback)
📥 [FlutterInstance] Received response from _flutter.screenshot
   Response type: Success
   Response JSON keys: [screenshot]
✅ [FlutterInstance] Screenshot decoded: 245678 bytes (from fallback)
```

### Error Scenarios

**Extension Not Found**
```
⚠️  [FlutterInstance] runtime_ai_dev_tools extension not available: Sentinel: MethodNotFound
   Falling back to built-in _flutter.screenshot extension
```
- Normal when app doesn't have `RuntimeAiDevTools.init()`
- System falls back to built-in extension

**No Screenshot Data**
```
❌ [FlutterInstance] No screenshot data in _flutter.screenshot response
```
- Screenshot failed completely
- Check if app is rendering properly

**Complete Failure**
```
❌ [FlutterInstance] Screenshot failed with error: StateError: ...
```
- Catch-all for unexpected errors
- Shows full error message for debugging

## Tap Logging

### Example Output

```
🔍 [FlutterInstance] tap() called at coordinates (400.0, 300.0) for instance abc-123
🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.tap
   Parameters: x=400.0, y=300.0
📥 [FlutterInstance] Received response from runtime_ai_dev_tools.tap
   Response type: Success
   Response JSON: {status: success, x: 400.0, y: 300.0}
✅ [FlutterInstance] Tap successful via runtime_ai_dev_tools
   Coordinates confirmed: x=400.0, y=300.0
```

### What the Logs Tell You

**Step 1: Method Called**
```
🔍 [FlutterInstance] tap() called at coordinates (400.0, 300.0) for instance abc-123
```
- Shows exact coordinates being tapped
- Confirms instance ID

**Step 2: Extension Call**
```
🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.tap
   Parameters: x=400.0, y=400.0
```
- Shows which extension is being called
- Displays parameters being sent

**Step 3: Response Analysis**
```
📥 [FlutterInstance] Received response from runtime_ai_dev_tools.tap
   Response type: Success
   Response JSON: {status: success, x: 400.0, y: 300.0}
```
- Full JSON response for debugging
- Can verify coordinates were received correctly

**Step 4: Confirmation**
```
✅ [FlutterInstance] Tap successful via runtime_ai_dev_tools
   Coordinates confirmed: x=400.0, y=300.0
```
- Confirms tap was dispatched successfully
- Shows which method was used (runtime_ai_dev_tools vs evaluator)

### Fallback Scenario

If runtime_ai_dev_tools is not available:

```
⚠️  [FlutterInstance] runtime_ai_dev_tools.tap extension not available: Sentinel: MethodNotFound
   Falling back to VM Service evaluator approach
🔧 [FlutterInstance] Using VM Service evaluator fallback
   Calling evaluator.tap(400.0, 300.0)
✅ [FlutterInstance] Tap successful via VM Service evaluator
```

## Using the Logs for Debugging

### Scenario 1: Tap Shows Ripple but Doesn't Work

**Look for:**
```
✅ [FlutterInstance] Tap successful via runtime_ai_dev_tools
   Coordinates confirmed: x=801.0, y=830.0
```

**What it means:**
- The service extension received the tap command successfully
- The coordinates were processed correctly
- The issue is likely in how the tap event is being dispatched

**Next steps:**
1. Check the runtime_ai_dev_tools implementation in `tap_extension.dart`
2. Verify `PointerDownEvent` and `PointerUpEvent` are being created correctly
3. Ensure events are using minimal parameters (position only)

### Scenario 2: Screenshot Returns Null

**Look for:**
```
⚠️  [FlutterInstance] runtime_ai_dev_tools extension not available: ...
🔧 [FlutterInstance] Attempting to call _flutter.screenshot (fallback)
❌ [FlutterInstance] No screenshot data in _flutter.screenshot response
```

**What it means:**
- runtime_ai_dev_tools not available (expected if not initialized)
- Built-in extension also failed
- Possible platform issue (web with HTML renderer)

**Next steps:**
1. Check if app has `RuntimeAiDevTools.init()` for best results
2. Verify platform supports screenshots (web needs CanvasKit)
3. Check if app is fully rendered

### Scenario 3: VM Service Not Connected

**Look for:**
```
⚠️  [FlutterInstance] VM Service not connected, attempting to connect...
❌ [FlutterInstance] Failed to connect to VM Service
```

**What it means:**
- Flutter app's VM Service URI wasn't captured at startup
- Or connection to VM Service failed

**Next steps:**
1. Check if `flutter run` output included VM Service URI
2. Verify app is in debug or profile mode (not release)
3. Check firewall/network settings

### Scenario 4: Extension Returns Wrong Status

**Look for:**
```
📥 [FlutterInstance] Received response from runtime_ai_dev_tools.tap
   Response type: Success
   Response JSON: {status: error, message: ...}
⚠️  [FlutterInstance] Tap response status is not success: error
```

**What it means:**
- Extension was found and called
- But it returned an error status
- Full error in the response JSON

**Next steps:**
1. Read the error message in the response
2. Check runtime_ai_dev_tools implementation
3. Verify parameters are valid

## Interpreting Response Types

### Response.type Values

| Value | Meaning |
|-------|---------|
| `Success` | Service extension call succeeded |
| `Error` | Service extension call failed |
| `Sentinel` | Extension not found or not registered |

### Response.json Structure

**For runtime_ai_dev_tools.screenshot:**
```json
{
  "status": "success",
  "image": "base64EncodedPngString"
}
```

**For runtime_ai_dev_tools.tap:**
```json
{
  "status": "success",
  "x": "400.0",
  "y": "300.0"
}
```

**For _flutter.screenshot (fallback):**
```json
{
  "screenshot": "base64EncodedPngString"
}
```

## Enabling/Disabling Logs

### Current Implementation
All logs use `print()` which outputs to:
- Terminal where MCP server is running
- Flutter app console (for service extension logs)
- TUI test app logs (if using tui_test_app)

### To Disable Logs (Not Recommended)
Remove or comment out `print()` statements in `flutter_instance.dart`.

### To Add More Logs
Follow the pattern:
```dart
print('🔍 [FlutterInstance] Your message here');
print('   Additional context with indentation');
```

Use appropriate symbols from the table above.

## Viewing Logs

### In Terminal (MCP Server)
```bash
# When running the MCP server directly
dart run bin/mcp_server.dart

# Logs will appear inline with MCP protocol messages
```

### In TUI Test App
Logs appear in the scrollable output area of the TUI interface.

### In Flutter App (Service Extension Side)
```bash
flutter run -d chrome

# Logs from runtime_ai_dev_tools appear in Flutter console
# Look for [runtime_ai_dev_tools] prefix
```

## Log Flow Diagram

### Screenshot Flow
```
🔍 screenshot() called
  ↓
⏱️  Wait 500ms
  ↓
🔧 Call ext.runtime_ai_dev_tools.screenshot
  ↓
📥 Receive response
  ├─ ✅ Success (status: success)
  │   └─ ✅ Decode bytes
  └─ ⚠️  Not available
      ↓
    🔧 Call _flutter.screenshot (fallback)
      ↓
    📥 Receive response
      ├─ ✅ Success
      │   └─ ✅ Decode bytes (from fallback)
      └─ ❌ Failed
```

### Tap Flow
```
🔍 tap(x, y) called
  ↓
🔧 Call ext.runtime_ai_dev_tools.tap
  ↓
📥 Receive response
  ├─ ✅ Success (status: success)
  │   └─ ✅ Coordinates confirmed
  └─ ⚠️  Not available
      ↓
    🔧 Use VM Service evaluator
      ↓
      ├─ ✅ Evaluation successful
      └─ ❌ Evaluation failed
```

## Summary

The logging system provides:
- **Visibility**: See exactly what's happening at each step
- **Debugging**: Identify where failures occur
- **Verification**: Confirm which extension is being used
- **Troubleshooting**: Clear error messages with context

All logs follow a consistent format with visual indicators (emojis) for quick scanning and categorization by severity/type.
