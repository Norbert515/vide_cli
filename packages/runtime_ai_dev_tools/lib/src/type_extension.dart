import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Special key escape sequences supported by the type extension
const _specialKeys = {
  '{backspace}',
  '{enter}',
  '{tab}',
  '{escape}',
  '{left}',
  '{right}',
  '{up}',
  '{down}',
};

/// Track current text input state
int? _currentClientId;
TextEditingValue? _currentValue;
bool _isHandlerInstalled = false;

/// Registers the type service extension
void registerTypeExtension() {
  print('🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.type');

  // Install the text input handler to track client state
  _installTextInputHandler();

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.type',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] type extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');
      print('   Current client ID: $_currentClientId');
      print('   Current value: ${_currentValue?.text}');

      try {
        final text = parameters['text'];

        if (text == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameter: text',
          );
        }

        await _simulateTyping(text);

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'text': text,
            'finalText': _currentValue?.text ?? '',
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] Error in type extension: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to simulate typing: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Install a message handler to intercept text input channel messages
/// This allows us to track the current client ID and editing state
void _installTextInputHandler() {
  if (_isHandlerInstalled) return;
  _isHandlerInstalled = true;

  print(
    '🔧 [RuntimeAiDevTools] Installing text input handler on ${SystemChannels.textInput.name}',
  );

  ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
    SystemChannels.textInput.name,
    (ByteData? message) async {
      if (message != null) {
        try {
          final call = SystemChannels.textInput.codec.decodeMethodCall(message);

          switch (call.method) {
            case 'TextInput.setClient':
              final args = call.arguments as List<dynamic>;
              _currentClientId = args[0] as int;
              print(
                '📝 [RuntimeAiDevTools] TextInput.setClient: $_currentClientId',
              );
              break;
            case 'TextInput.setEditingState':
              _currentValue = TextEditingValue.fromJSON(
                Map<String, dynamic>.from(call.arguments as Map),
              );
              print(
                '📝 [RuntimeAiDevTools] TextInput.setEditingState: "${_currentValue?.text}"',
              );
              break;
            case 'TextInput.clearClient':
              print(
                '📝 [RuntimeAiDevTools] TextInput.clearClient (was: $_currentClientId)',
              );
              _currentClientId = null;
              _currentValue = null;
              break;
          }
        } catch (e) {
          print('⚠️  [RuntimeAiDevTools] Error decoding text input message: $e');
        }
      }

      // Return null - we're just observing, not intercepting
      return null;
    },
  );

  print('✅ [RuntimeAiDevTools] Text input handler installed');
}

/// Simulates typing the given text character-by-character with special key support
Future<void> _simulateTyping(String text) async {
  print('⌨️  [RuntimeAiDevTools] _simulateTyping called with: "$text"');

  final tokens = _parseText(text);
  print('   Parsed ${tokens.length} tokens');

  for (final token in tokens) {
    if (token.isSpecialKey) {
      print('   Processing special key: ${token.value}');
      await _handleSpecialKey(token.value);
    } else {
      // Type each character individually
      for (final char in token.value.split('')) {
        print('   Typing character: "$char"');
        await _insertCharacter(char);
        // Small delay between characters for visibility
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  print('✅ [RuntimeAiDevTools] Typing simulation complete');
  print('   Final text: "${_currentValue?.text}"');
}

/// Parse text into tokens (regular text and special keys)
List<_TypeToken> _parseText(String text) {
  final tokens = <_TypeToken>[];
  var currentIndex = 0;
  var normalText = StringBuffer();

  while (currentIndex < text.length) {
    // Check if this is the start of a special key
    var foundSpecialKey = false;
    for (final key in _specialKeys) {
      if (text.substring(currentIndex).toLowerCase().startsWith(key)) {
        // Save any accumulated normal text first
        if (normalText.isNotEmpty) {
          tokens.add(_TypeToken(normalText.toString(), isSpecialKey: false));
          normalText = StringBuffer();
        }
        // Add the special key token
        tokens.add(_TypeToken(key, isSpecialKey: true));
        currentIndex += key.length;
        foundSpecialKey = true;
        break;
      }
    }

    if (!foundSpecialKey) {
      normalText.write(text[currentIndex]);
      currentIndex++;
    }
  }

  // Don't forget any trailing normal text
  if (normalText.isNotEmpty) {
    tokens.add(_TypeToken(normalText.toString(), isSpecialKey: false));
  }

  return tokens;
}

/// Token representing either normal text or a special key
class _TypeToken {
  final String value;
  final bool isSpecialKey;

  _TypeToken(this.value, {required this.isSpecialKey});
}

/// Insert a single character at the current cursor position
Future<void> _insertCharacter(String char) async {
  // Get current state or use defaults
  final currentText = _currentValue?.text ?? '';
  final selection =
      _currentValue?.selection ??
      TextSelection.collapsed(offset: currentText.length);

  // Insert character at cursor position or replace selection
  final newText = currentText.replaceRange(selection.start, selection.end, char);
  final newOffset = selection.start + char.length;

  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );

  await _sendEditingState(newValue);
  _currentValue = newValue;
}

/// Handle special key actions
Future<void> _handleSpecialKey(String key) async {
  switch (key.toLowerCase()) {
    case '{backspace}':
      await _handleBackspace();
      break;
    case '{enter}':
      await _handleEnter();
      break;
    case '{tab}':
      await _insertCharacter('\t');
      break;
    case '{escape}':
      await _handleEscape();
      break;
    case '{left}':
      await _moveCursor(-1);
      break;
    case '{right}':
      await _moveCursor(1);
      break;
    case '{up}':
      await _moveCursorVertically(-1);
      break;
    case '{down}':
      await _moveCursorVertically(1);
      break;
  }
  // Small delay after special keys
  await Future.delayed(const Duration(milliseconds: 50));
}

/// Handle backspace - delete character before cursor or delete selection
Future<void> _handleBackspace() async {
  if (_currentValue == null) {
    print('   ⚠️  No current value for backspace');
    return;
  }

  final text = _currentValue!.text;
  final selection = _currentValue!.selection;

  String newText;
  int newOffset;

  if (selection.isCollapsed && selection.start > 0) {
    // Delete character before cursor
    newText =
        text.substring(0, selection.start - 1) + text.substring(selection.start);
    newOffset = selection.start - 1;
    print('   Backspace: deleted char at ${selection.start - 1}');
  } else if (!selection.isCollapsed) {
    // Delete selected text
    newText = text.replaceRange(selection.start, selection.end, '');
    newOffset = selection.start;
    print(
      '   Backspace: deleted selection ${selection.start}-${selection.end}',
    );
  } else {
    // Cursor at start, nothing to delete
    print('   Backspace: cursor at start, nothing to delete');
    return;
  }

  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );

  await _sendEditingState(newValue);
  _currentValue = newValue;
}

/// Handle enter - insert newline or trigger action for single-line fields
Future<void> _handleEnter() async {
  // For now, just insert a newline character
  // In a more sophisticated implementation, we could check if this is a
  // single-line field and trigger TextInputAction.done instead
  print('   Enter: inserting newline');
  await _insertCharacter('\n');

  // Also try to trigger the done action for single-line text fields
  // This helps with form submission
  await _performAction(TextInputAction.done);
}

/// Handle escape - typically clears focus
Future<void> _handleEscape() async {
  print('   Escape: sending hide keyboard action');
  // Send hide action - this typically clears focus
  try {
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        const MethodCall('TextInput.hide'),
      ),
      (ByteData? reply) {},
    );
  } catch (e) {
    print('   ⚠️  Error sending hide: $e');
  }
}

/// Move cursor horizontally by delta positions
Future<void> _moveCursor(int delta) async {
  if (_currentValue == null) {
    print('   ⚠️  No current value for cursor movement');
    return;
  }

  final text = _currentValue!.text;
  final selection = _currentValue!.selection;

  int newOffset;
  if (selection.isCollapsed) {
    newOffset = (selection.start + delta).clamp(0, text.length);
  } else {
    // If there's a selection, moving collapses it
    newOffset = delta < 0 ? selection.start : selection.end;
  }

  print('   Moving cursor: ${selection.start} -> $newOffset');

  final newValue = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: newOffset),
  );

  await _sendEditingState(newValue);
  _currentValue = newValue;
}

/// Move cursor vertically (for multiline text fields)
/// This is a simplified implementation that moves to start/end of text
Future<void> _moveCursorVertically(int delta) async {
  if (_currentValue == null) {
    print('   ⚠️  No current value for vertical cursor movement');
    return;
  }

  final text = _currentValue!.text;
  final selection = _currentValue!.selection;

  // Find current line boundaries
  final currentOffset = selection.isCollapsed ? selection.start : selection.end;

  // Find the start of the current line
  int lineStart = currentOffset;
  while (lineStart > 0 && text[lineStart - 1] != '\n') {
    lineStart--;
  }

  // Find the end of the current line
  int lineEnd = currentOffset;
  while (lineEnd < text.length && text[lineEnd] != '\n') {
    lineEnd++;
  }

  // Column position within the line
  final column = currentOffset - lineStart;

  int newOffset;
  if (delta < 0) {
    // Move up
    if (lineStart == 0) {
      // Already on first line, move to start
      newOffset = 0;
    } else {
      // Find the previous line
      int prevLineEnd = lineStart - 1; // Skip the newline
      int prevLineStart = prevLineEnd;
      while (prevLineStart > 0 && text[prevLineStart - 1] != '\n') {
        prevLineStart--;
      }
      // Move to same column or end of previous line
      final prevLineLength = prevLineEnd - prevLineStart;
      newOffset = prevLineStart + column.clamp(0, prevLineLength);
    }
  } else {
    // Move down
    if (lineEnd >= text.length) {
      // Already on last line, move to end
      newOffset = text.length;
    } else {
      // Find the next line
      int nextLineStart = lineEnd + 1; // Skip the newline
      int nextLineEnd = nextLineStart;
      while (nextLineEnd < text.length && text[nextLineEnd] != '\n') {
        nextLineEnd++;
      }
      // Move to same column or end of next line
      final nextLineLength = nextLineEnd - nextLineStart;
      newOffset = nextLineStart + column.clamp(0, nextLineLength);
    }
  }

  print(
    '   Moving cursor vertically: ${selection.start} -> $newOffset (delta: $delta)',
  );

  final newValue = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: newOffset),
  );

  await _sendEditingState(newValue);
  _currentValue = newValue;
}

/// Perform a text input action (like done, next, etc.)
Future<void> _performAction(TextInputAction action) async {
  final clientId = _currentClientId ?? -1;

  print('   Performing action: $action (client: $clientId)');

  try {
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.performAction', <dynamic>[
          clientId,
          action.toString(),
        ]),
      ),
      (ByteData? reply) {},
    );
  } catch (e) {
    print('   ⚠️  Error performing action: $e');
  }
}

/// Send a new editing state to the text input channel
Future<void> _sendEditingState(TextEditingValue value) async {
  // Use client ID -1 if we don't have one (works in debug mode)
  final clientId = _currentClientId ?? -1;

  print(
    '   Sending editing state: "${value.text}" (cursor: ${value.selection.start}, client: $clientId)',
  );

  try {
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingState', <dynamic>[
          clientId,
          value.toJSON(),
        ]),
      ),
      (ByteData? reply) {},
    );
  } catch (e) {
    print('   ❌ Error sending editing state: $e');
    rethrow;
  }
}
