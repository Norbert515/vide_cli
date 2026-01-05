import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Pattern to match special key sequences like {enter}, {ctrl+c}, {alt+shift+tab}
final _specialKeyPattern = RegExp(r'\{([^}]+)\}');

/// Global text input state tracker
_TextInputTracker? _textInputTracker;

/// Registers the type service extension
void registerTypeExtension() {
  print('🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.type');

  // Install the text input tracker to monitor IME state
  _textInputTracker = _TextInputTracker.install();

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.type',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] type extension called');
      print('   Parameters: $parameters');

      try {
        final text = parameters['text'];

        if (text == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameter: text',
          );
        }

        final result = await _simulateTyping(text);

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'text': text,
            'method': result.name,
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

  // Register status extension
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.type_status',
    (String method, Map<String, String> parameters) async {
      final tracker = _textInputTracker;
      return developer.ServiceExtensionResponse.result(
        json.encode({
          'hasActiveClient': tracker?.hasActiveClient ?? false,
          'clientId': tracker?.currentClientId,
          'currentText': tracker?.currentValue?.text,
          'cursorPosition': tracker?.currentValue?.selection.baseOffset,
        }),
      );
    },
  );
}

/// Injection method used
enum _InjectionMethod {
  imeChannel, // Low-level IME channel (most reliable for TextFields)
  textInputClient, // Direct TextInputClient.updateEditingValue
  rawKeyEvent, // Raw keyboard events (for terminals, games)
}

/// Simulates typing the given text with special key support.
///
/// Strategy (in order of preference):
/// 1. IME Channel: If there's an active TextInput client, inject via channel
/// 2. TextInputClient: Direct widget API if found in tree
/// 3. Raw Key Events: For terminals, games, and Focus-based widgets
Future<_InjectionMethod> _simulateTyping(String text) async {
  final tokens = _parseText(text);
  final tracker = _textInputTracker;
  final hasImeClient = tracker?.hasActiveClient ?? false;

  _InjectionMethod methodUsed = _InjectionMethod.rawKeyEvent;

  for (final token in tokens) {
    if (token.isSpecialKey) {
      // Special keys always use raw key events (or IME for some like backspace)
      await _handleSpecialKey(token.value, tracker: tracker);
    } else if (hasImeClient && tracker != null) {
      // Primary: Use low-level IME channel injection
      await tracker.injectText(token.value);
      methodUsed = _InjectionMethod.imeChannel;
    } else {
      // Try to find TextInputClient in widget tree
      final textInputClient = _findTextInputClient();
      if (textInputClient != null) {
        await _insertViaTextInputClient(textInputClient, token.value);
        methodUsed = _InjectionMethod.textInputClient;
      } else {
        // Fallback: raw key events for Focus-based widgets
        for (final char in token.value.split('')) {
          await _simulateCharacterKeyPress(char);
          await Future.delayed(const Duration(milliseconds: 30));
        }
        methodUsed = _InjectionMethod.rawKeyEvent;
      }
    }
  }

  print('📤 [RuntimeAiDevTools] Typing complete, method: ${methodUsed.name}');
  return methodUsed;
}

// ============================================================================
// Text Input Tracker - Intercepts IME channel to track client state
// ============================================================================

/// Tracks TextInput state by intercepting outgoing messages.
///
/// Uses `TextInput.setChannel()` to wrap the text input channel and monitor
/// when TextInput clients are created/destroyed and their current state.
class _TextInputTracker {
  _TextInputTracker._();

  int? _currentClientId;
  TextEditingValue? _currentValue;
  _InterceptingBinaryMessenger? _messenger;

  bool get hasActiveClient => _currentClientId != null;
  int? get currentClientId => _currentClientId;
  TextEditingValue? get currentValue => _currentValue;

  /// Install the tracker by wrapping the TextInput channel
  static _TextInputTracker install() {
    final tracker = _TextInputTracker._();
    tracker._install();
    return tracker;
  }

  void _install() {
    // Wrap the default binary messenger to intercept OUTGOING messages
    final defaultMessenger = ServicesBinding.instance.defaultBinaryMessenger;
    _messenger = _InterceptingBinaryMessenger(
      defaultMessenger,
      onTextInputMessage: _handleOutgoingMessage,
    );

    // Replace the TextInput channel with our intercepting version
    final interceptingChannel = MethodChannel(
      'flutter/textinput',
      const JSONMethodCodec(),
      _messenger,
    );
    TextInput.setChannel(interceptingChannel);

    print('🔧 [RuntimeAiDevTools] TextInput tracker installed');
  }

  void _handleOutgoingMessage(MethodCall call) {
    switch (call.method) {
      case 'TextInput.setClient':
        final args = call.arguments as List<dynamic>;
        _currentClientId = args[0] as int;
        print('🔧 [RuntimeAiDevTools] TextInput client set: $_currentClientId');

      case 'TextInput.setEditingState':
        final args = call.arguments as Map<dynamic, dynamic>;
        _currentValue = _decodeEditingValue(args);

      case 'TextInput.clearClient':
        print(
            '🔧 [RuntimeAiDevTools] TextInput client cleared (was: $_currentClientId)');
        _currentClientId = null;
        _currentValue = null;
    }
  }

  /// Inject text via the IME channel (simulates platform → framework message)
  Future<bool> injectText(String text) async {
    if (_currentClientId == null) return false;

    final current = _currentValue ?? TextEditingValue.empty;
    final selection = current.selection;

    // Calculate new text
    String newText;
    int newCursorPos;

    if (selection.isValid && selection.start >= 0) {
      newText = current.text.replaceRange(selection.start, selection.end, text);
      newCursorPos = selection.start + text.length;
    } else {
      newText = current.text + text;
      newCursorPos = newText.length;
    }

    final newValue = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    return _sendEditingState(newValue);
  }

  /// Delete characters (backspace)
  Future<bool> deleteBackward({int count = 1}) async {
    if (_currentClientId == null || _currentValue == null) return false;

    final current = _currentValue!;
    final selection = current.selection;

    if (!selection.isValid || selection.start < 0) return false;

    String newText;
    int newCursorPos;

    if (selection.isCollapsed) {
      final deleteStart = (selection.start - count).clamp(0, selection.start);
      newText = current.text.replaceRange(deleteStart, selection.start, '');
      newCursorPos = deleteStart;
    } else {
      newText = current.text.replaceRange(selection.start, selection.end, '');
      newCursorPos = selection.start;
    }

    return _sendEditingState(TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    ));
  }

  /// Send editing state to the framework (simulates platform message)
  Future<bool> _sendEditingState(TextEditingValue value) async {
    if (_currentClientId == null) return false;

    _currentValue = value;

    final encoded = const JSONMethodCodec().encodeMethodCall(
      MethodCall('TextInputClient.updateEditingState', <dynamic>[
        _currentClientId,
        _encodeEditingValue(value),
      ]),
    );

    try {
      ServicesBinding.instance.channelBuffers.push(
        'flutter/textinput',
        encoded,
        (ByteData? reply) {},
      );
      return true;
    } catch (e) {
      print('❌ [RuntimeAiDevTools] Error sending editing state: $e');
      return false;
    }
  }

  Map<String, dynamic> _encodeEditingValue(TextEditingValue value) {
    return <String, dynamic>{
      'text': value.text,
      'selectionBase': value.selection.baseOffset,
      'selectionExtent': value.selection.extentOffset,
      'selectionAffinity': value.selection.affinity.toString().split('.').last,
      'selectionIsDirectional': value.selection.isDirectional,
      'composingBase': value.composing.start,
      'composingExtent': value.composing.end,
    };
  }

  TextEditingValue _decodeEditingValue(Map<dynamic, dynamic> encoded) {
    return TextEditingValue(
      text: encoded['text'] as String? ?? '',
      selection: TextSelection(
        baseOffset: encoded['selectionBase'] as int? ?? -1,
        extentOffset: encoded['selectionExtent'] as int? ?? -1,
        isDirectional: encoded['selectionIsDirectional'] as bool? ?? false,
      ),
      composing: TextRange(
        start: encoded['composingBase'] as int? ?? -1,
        end: encoded['composingExtent'] as int? ?? -1,
      ),
    );
  }
}

/// BinaryMessenger wrapper that intercepts outgoing messages to flutter/textinput
class _InterceptingBinaryMessenger implements BinaryMessenger {
  final BinaryMessenger _delegate;
  final void Function(MethodCall call) onTextInputMessage;

  static const _textInputChannel = 'flutter/textinput';
  static const _codec = JSONMethodCodec();

  _InterceptingBinaryMessenger(this._delegate,
      {required this.onTextInputMessage});

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel == _textInputChannel && message != null) {
      try {
        final call = _codec.decodeMethodCall(message);
        onTextInputMessage(call);
      } catch (e) {
        // Ignore decode errors
      }
    }
    return _delegate.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    _delegate.setMessageHandler(channel, handler);
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    return _delegate.handlePlatformMessage(channel, data, callback);
  }
}

// ============================================================================
// Widget Tree TextInputClient Detection (Fallback)
// ============================================================================

/// Find a TextInputClient in the widget tree from the focused element.
/// Searches both descendants AND ancestors since EditableTextState is a child.
TextInputClient? _findTextInputClient() {
  final focusNode = FocusManager.instance.primaryFocus;
  if (focusNode == null) return null;

  final context = focusNode.context;
  if (context == null) return null;

  // Check if focused element itself is TextInputClient
  if (context is StatefulElement && context.state is TextInputClient) {
    return context.state as TextInputClient;
  }

  // Search DESCENDANTS (EditableTextState is a child of Focus)
  TextInputClient? client;
  void visitChildren(Element element) {
    if (client != null) return;
    if (element is StatefulElement && element.state is TextInputClient) {
      client = element.state as TextInputClient;
      return;
    }
    element.visitChildren(visitChildren);
  }

  (context as Element).visitChildren(visitChildren);
  if (client != null) return client;

  // Search ANCESTORS as fallback
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is TextInputClient) {
      client = element.state as TextInputClient;
      return false;
    }
    return true;
  });

  return client;
}

/// Insert text via TextInputClient (direct widget API)
Future<void> _insertViaTextInputClient(
    TextInputClient client, String text) async {
  final current = client.currentTextEditingValue ?? TextEditingValue.empty;
  final selection = current.selection;

  final newText = selection.isValid
      ? current.text.replaceRange(selection.start, selection.end, text)
      : current.text + text;

  final newCursorPosition =
      selection.isValid ? selection.start + text.length : newText.length;

  final newValue = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newCursorPosition),
  );

  client.updateEditingValue(newValue);
  await Future.delayed(const Duration(milliseconds: 30));
}

// ============================================================================
// Token Parsing
// ============================================================================

List<_TypeToken> _parseText(String text) {
  final tokens = <_TypeToken>[];
  var lastEnd = 0;

  for (final match in _specialKeyPattern.allMatches(text)) {
    if (match.start > lastEnd) {
      tokens.add(_TypeToken(text.substring(lastEnd, match.start),
          isSpecialKey: false));
    }
    tokens.add(_TypeToken(match.group(1)!, isSpecialKey: true));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    tokens.add(_TypeToken(text.substring(lastEnd), isSpecialKey: false));
  }

  return tokens;
}

class _TypeToken {
  final String value;
  final bool isSpecialKey;
  _TypeToken(this.value, {required this.isSpecialKey});
}

// ============================================================================
// Special Key Handling
// ============================================================================

/// Handle special key actions
Future<void> _handleSpecialKey(String keySpec,
    {_TextInputTracker? tracker}) async {
  final parts = keySpec.toLowerCase().split('+');

  var ctrl = false;
  var alt = false;
  var shift = false;
  var meta = false;
  String? mainKey;

  for (final part in parts) {
    switch (part) {
      case 'ctrl' || 'control':
        ctrl = true;
      case 'alt' || 'option':
        alt = true;
      case 'shift':
        shift = true;
      case 'meta' || 'cmd' || 'command' || 'win' || 'super':
        meta = true;
      default:
        mainKey = part;
    }
  }

  if (mainKey == null) return;

  // For some keys, use IME if available and no modifiers
  if (tracker != null && tracker.hasActiveClient && !ctrl && !alt && !meta) {
    switch (mainKey) {
      case 'backspace':
        await tracker.deleteBackward();
        return;
      case 'enter' || 'return':
        await tracker.injectText('\n');
        return;
      case 'tab':
        await tracker.injectText('\t');
        return;
    }
  }

  // Fall back to raw key events
  final keyInfo = _getSpecialKeyInfo(mainKey);
  if (keyInfo == null) return;

  // Press modifiers
  if (ctrl)
    await _sendKeyDown(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft);
  if (alt)
    await _sendKeyDown(
        physicalKey: PhysicalKeyboardKey.altLeft,
        logicalKey: LogicalKeyboardKey.altLeft);
  if (shift)
    await _sendKeyDown(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft);
  if (meta)
    await _sendKeyDown(
        physicalKey: PhysicalKeyboardKey.metaLeft,
        logicalKey: LogicalKeyboardKey.metaLeft);

  if (ctrl || alt || shift || meta) {
    await Future.delayed(const Duration(milliseconds: 5));
  }

  // Press main key
  await _sendKeyDown(
    physicalKey: keyInfo.physicalKey,
    logicalKey: keyInfo.logicalKey,
    character: keyInfo.character,
  );
  await Future.delayed(const Duration(milliseconds: 10));
  await _sendKeyUp(
      physicalKey: keyInfo.physicalKey, logicalKey: keyInfo.logicalKey);

  // Release modifiers
  if (meta) {
    await Future.delayed(const Duration(milliseconds: 5));
    await _sendKeyUp(
        physicalKey: PhysicalKeyboardKey.metaLeft,
        logicalKey: LogicalKeyboardKey.metaLeft);
  }
  if (shift) {
    await Future.delayed(const Duration(milliseconds: 5));
    await _sendKeyUp(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft);
  }
  if (alt) {
    await Future.delayed(const Duration(milliseconds: 5));
    await _sendKeyUp(
        physicalKey: PhysicalKeyboardKey.altLeft,
        logicalKey: LogicalKeyboardKey.altLeft);
  }
  if (ctrl) {
    await Future.delayed(const Duration(milliseconds: 5));
    await _sendKeyUp(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft);
  }

  await Future.delayed(const Duration(milliseconds: 30));
}

// ============================================================================
// Raw Key Event Simulation
// ============================================================================

Future<void> _simulateCharacterKeyPress(String char) async {
  final keyInfo = _getKeyInfoForCharacter(char);
  if (keyInfo == null) return;

  if (keyInfo.needsShift) {
    await _sendKeyDown(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft);
    await Future.delayed(const Duration(milliseconds: 5));
  }

  await _sendKeyDown(
      physicalKey: keyInfo.physicalKey,
      logicalKey: keyInfo.logicalKey,
      character: char);
  await Future.delayed(const Duration(milliseconds: 10));
  await _sendKeyUp(
      physicalKey: keyInfo.physicalKey, logicalKey: keyInfo.logicalKey);

  if (keyInfo.needsShift) {
    await Future.delayed(const Duration(milliseconds: 5));
    await _sendKeyUp(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft);
  }
}

Future<bool> _sendKeyDown({
  required PhysicalKeyboardKey physicalKey,
  required LogicalKeyboardKey logicalKey,
  String? character,
}) async {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;

  final keyEvent = KeyDownEvent(
    physicalKey: physicalKey,
    logicalKey: logicalKey,
    character: character,
    timeStamp: Duration.zero,
  );

  final onKeyEvent = primaryFocus.onKeyEvent;
  if (onKeyEvent != null) {
    final result = onKeyEvent(primaryFocus, keyEvent);
    // For xterm-style widgets, character insertion happens in onKeyEvent
    if (keyEvent.character != null && keyEvent.character!.isNotEmpty) {
      return true;
    }
    return result == KeyEventResult.handled;
  }

  // Fallback: HardwareKeyboard API
  return ServicesBinding.instance.keyEventManager.handleKeyData(
    ui.KeyData(
      type: ui.KeyEventType.down,
      physical: physicalKey.usbHidUsage,
      logical: logicalKey.keyId,
      timeStamp: Duration.zero,
      character: character,
      synthesized: true,
    ),
  );
}

Future<bool> _sendKeyUp({
  required PhysicalKeyboardKey physicalKey,
  required LogicalKeyboardKey logicalKey,
}) async {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;

  final keyEvent = KeyUpEvent(
    physicalKey: physicalKey,
    logicalKey: logicalKey,
    timeStamp: Duration.zero,
  );

  final onKeyEvent = primaryFocus.onKeyEvent;
  if (onKeyEvent != null) {
    final result = onKeyEvent(primaryFocus, keyEvent);
    return result == KeyEventResult.handled;
  }

  return ServicesBinding.instance.keyEventManager.handleKeyData(
    ui.KeyData(
      type: ui.KeyEventType.up,
      physical: physicalKey.usbHidUsage,
      logical: logicalKey.keyId,
      timeStamp: Duration.zero,
      character: null,
      synthesized: true,
    ),
  );
}

// ============================================================================
// Key Info Structures and Mappings
// ============================================================================

class _SpecialKeyInfo {
  final PhysicalKeyboardKey physicalKey;
  final LogicalKeyboardKey logicalKey;
  final String? character;
  const _SpecialKeyInfo(this.physicalKey, this.logicalKey, [this.character]);
}

_SpecialKeyInfo? _getSpecialKeyInfo(String key) {
  return switch (key) {
    'enter' || 'return' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.enter, LogicalKeyboardKey.enter, '\n'),
    'tab' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.tab, LogicalKeyboardKey.tab, '\t'),
    'backspace' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.backspace, LogicalKeyboardKey.backspace),
    'delete' || 'del' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.delete, LogicalKeyboardKey.delete),
    'escape' || 'esc' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.escape, LogicalKeyboardKey.escape),
    'space' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.space, LogicalKeyboardKey.space, ' '),
    'left' || 'arrowleft' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
    'right' || 'arrowright' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
    'up' || 'arrowup' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowUp),
    'down' || 'arrowdown' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowDown),
    'home' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.home, LogicalKeyboardKey.home),
    'end' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.end, LogicalKeyboardKey.end),
    'pageup' || 'pgup' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.pageUp, LogicalKeyboardKey.pageUp),
    'pagedown' || 'pgdn' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.pageDown, LogicalKeyboardKey.pageDown),
    'insert' || 'ins' => const _SpecialKeyInfo(
        PhysicalKeyboardKey.insert, LogicalKeyboardKey.insert),
    'f1' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f1, LogicalKeyboardKey.f1),
    'f2' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f2, LogicalKeyboardKey.f2),
    'f3' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f3, LogicalKeyboardKey.f3),
    'f4' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f4, LogicalKeyboardKey.f4),
    'f5' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f5, LogicalKeyboardKey.f5),
    'f6' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f6, LogicalKeyboardKey.f6),
    'f7' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f7, LogicalKeyboardKey.f7),
    'f8' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f8, LogicalKeyboardKey.f8),
    'f9' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f9, LogicalKeyboardKey.f9),
    'f10' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f10, LogicalKeyboardKey.f10),
    'f11' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f11, LogicalKeyboardKey.f11),
    'f12' =>
      const _SpecialKeyInfo(PhysicalKeyboardKey.f12, LogicalKeyboardKey.f12),
    _ when key.length == 1 => _getSingleCharSpecialKey(key),
    _ => null,
  };
}

_SpecialKeyInfo? _getSingleCharSpecialKey(String char) {
  final code = char.codeUnitAt(0);
  if (code >= 97 && code <= 122) {
    // a-z
    final keyInfo = _getLowercaseLetterKey(char);
    if (keyInfo != null)
      return _SpecialKeyInfo(keyInfo.physicalKey, keyInfo.logicalKey, char);
  }
  if (code >= 48 && code <= 57) {
    // 0-9
    final keyInfo = _getDigitKey(char);
    if (keyInfo != null)
      return _SpecialKeyInfo(keyInfo.physicalKey, keyInfo.logicalKey, char);
  }
  return null;
}

class _KeyInfo {
  final PhysicalKeyboardKey physicalKey;
  final LogicalKeyboardKey logicalKey;
  final bool needsShift;
  const _KeyInfo(
      {required this.physicalKey,
      required this.logicalKey,
      this.needsShift = false});
}

_KeyInfo? _getKeyInfoForCharacter(String char) {
  final code = char.codeUnitAt(0);

  if (code >= 97 && code <= 122) return _getLowercaseLetterKey(char);
  if (code >= 65 && code <= 90) return _getUppercaseLetterKey(char);
  if (code >= 48 && code <= 57) return _getDigitKey(char);
  if (char == ' ')
    return const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.space,
        logicalKey: LogicalKeyboardKey.space);

  return _getSymbolKey(char);
}

_KeyInfo? _getLowercaseLetterKey(String char) {
  final offset = char.codeUnitAt(0) - 97;
  final physical = _letterPhysicalKeys[offset];
  final logical = _letterLogicalKeys[offset];
  if (physical == null || logical == null) return null;
  return _KeyInfo(physicalKey: physical, logicalKey: logical);
}

_KeyInfo? _getUppercaseLetterKey(String char) {
  final offset = char.toLowerCase().codeUnitAt(0) - 97;
  final physical = _letterPhysicalKeys[offset];
  final logical = _letterLogicalKeys[offset];
  if (physical == null || logical == null) return null;
  return _KeyInfo(physicalKey: physical, logicalKey: logical, needsShift: true);
}

_KeyInfo? _getDigitKey(String char) {
  final offset = char.codeUnitAt(0) - 48;
  final physical = _digitPhysicalKeys[offset];
  final logical = _digitLogicalKeys[offset];
  if (physical == null || logical == null) return null;
  return _KeyInfo(physicalKey: physical, logicalKey: logical);
}

_KeyInfo? _getSymbolKey(String char) {
  return switch (char) {
    '-' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.minus,
        logicalKey: LogicalKeyboardKey.minus),
    '=' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.equal,
        logicalKey: LogicalKeyboardKey.equal),
    '[' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.bracketLeft,
        logicalKey: LogicalKeyboardKey.bracketLeft),
    ']' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.bracketRight,
        logicalKey: LogicalKeyboardKey.bracketRight),
    '\\' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.backslash,
        logicalKey: LogicalKeyboardKey.backslash),
    ';' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.semicolon,
        logicalKey: LogicalKeyboardKey.semicolon),
    "'" => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.quote,
        logicalKey: LogicalKeyboardKey.quoteSingle),
    '`' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.backquote,
        logicalKey: LogicalKeyboardKey.backquote),
    ',' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.comma,
        logicalKey: LogicalKeyboardKey.comma),
    '.' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.period,
        logicalKey: LogicalKeyboardKey.period),
    '/' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.slash,
        logicalKey: LogicalKeyboardKey.slash),
    '!' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.exclamation,
        needsShift: true),
    '@' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit2,
        logicalKey: LogicalKeyboardKey.at,
        needsShift: true),
    '#' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit3,
        logicalKey: LogicalKeyboardKey.numberSign,
        needsShift: true),
    '\$' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit4,
        logicalKey: LogicalKeyboardKey.dollar,
        needsShift: true),
    '%' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit5,
        logicalKey: LogicalKeyboardKey.percent,
        needsShift: true),
    '^' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit6,
        logicalKey: LogicalKeyboardKey.caret,
        needsShift: true),
    '&' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit7,
        logicalKey: LogicalKeyboardKey.ampersand,
        needsShift: true),
    '*' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit8,
        logicalKey: LogicalKeyboardKey.asterisk,
        needsShift: true),
    '(' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit9,
        logicalKey: LogicalKeyboardKey.parenthesisLeft,
        needsShift: true),
    ')' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.digit0,
        logicalKey: LogicalKeyboardKey.parenthesisRight,
        needsShift: true),
    '_' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.minus,
        logicalKey: LogicalKeyboardKey.underscore,
        needsShift: true),
    '+' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.equal,
        logicalKey: LogicalKeyboardKey.add,
        needsShift: true),
    '{' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.bracketLeft,
        logicalKey: LogicalKeyboardKey.braceLeft,
        needsShift: true),
    '}' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.bracketRight,
        logicalKey: LogicalKeyboardKey.braceRight,
        needsShift: true),
    '|' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.backslash,
        logicalKey: LogicalKeyboardKey.bar,
        needsShift: true),
    ':' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.semicolon,
        logicalKey: LogicalKeyboardKey.colon,
        needsShift: true),
    '"' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.quote,
        logicalKey: LogicalKeyboardKey.quote,
        needsShift: true),
    '~' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.backquote,
        logicalKey: LogicalKeyboardKey.tilde,
        needsShift: true),
    '<' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.comma,
        logicalKey: LogicalKeyboardKey.less,
        needsShift: true),
    '>' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.period,
        logicalKey: LogicalKeyboardKey.greater,
        needsShift: true),
    '?' => const _KeyInfo(
        physicalKey: PhysicalKeyboardKey.slash,
        logicalKey: LogicalKeyboardKey.question,
        needsShift: true),
    _ => null,
  };
}

const _letterPhysicalKeys = <int, PhysicalKeyboardKey>{
  0: PhysicalKeyboardKey.keyA,
  1: PhysicalKeyboardKey.keyB,
  2: PhysicalKeyboardKey.keyC,
  3: PhysicalKeyboardKey.keyD,
  4: PhysicalKeyboardKey.keyE,
  5: PhysicalKeyboardKey.keyF,
  6: PhysicalKeyboardKey.keyG,
  7: PhysicalKeyboardKey.keyH,
  8: PhysicalKeyboardKey.keyI,
  9: PhysicalKeyboardKey.keyJ,
  10: PhysicalKeyboardKey.keyK,
  11: PhysicalKeyboardKey.keyL,
  12: PhysicalKeyboardKey.keyM,
  13: PhysicalKeyboardKey.keyN,
  14: PhysicalKeyboardKey.keyO,
  15: PhysicalKeyboardKey.keyP,
  16: PhysicalKeyboardKey.keyQ,
  17: PhysicalKeyboardKey.keyR,
  18: PhysicalKeyboardKey.keyS,
  19: PhysicalKeyboardKey.keyT,
  20: PhysicalKeyboardKey.keyU,
  21: PhysicalKeyboardKey.keyV,
  22: PhysicalKeyboardKey.keyW,
  23: PhysicalKeyboardKey.keyX,
  24: PhysicalKeyboardKey.keyY,
  25: PhysicalKeyboardKey.keyZ,
};

const _letterLogicalKeys = <int, LogicalKeyboardKey>{
  0: LogicalKeyboardKey.keyA,
  1: LogicalKeyboardKey.keyB,
  2: LogicalKeyboardKey.keyC,
  3: LogicalKeyboardKey.keyD,
  4: LogicalKeyboardKey.keyE,
  5: LogicalKeyboardKey.keyF,
  6: LogicalKeyboardKey.keyG,
  7: LogicalKeyboardKey.keyH,
  8: LogicalKeyboardKey.keyI,
  9: LogicalKeyboardKey.keyJ,
  10: LogicalKeyboardKey.keyK,
  11: LogicalKeyboardKey.keyL,
  12: LogicalKeyboardKey.keyM,
  13: LogicalKeyboardKey.keyN,
  14: LogicalKeyboardKey.keyO,
  15: LogicalKeyboardKey.keyP,
  16: LogicalKeyboardKey.keyQ,
  17: LogicalKeyboardKey.keyR,
  18: LogicalKeyboardKey.keyS,
  19: LogicalKeyboardKey.keyT,
  20: LogicalKeyboardKey.keyU,
  21: LogicalKeyboardKey.keyV,
  22: LogicalKeyboardKey.keyW,
  23: LogicalKeyboardKey.keyX,
  24: LogicalKeyboardKey.keyY,
  25: LogicalKeyboardKey.keyZ,
};

const _digitPhysicalKeys = <int, PhysicalKeyboardKey>{
  0: PhysicalKeyboardKey.digit0,
  1: PhysicalKeyboardKey.digit1,
  2: PhysicalKeyboardKey.digit2,
  3: PhysicalKeyboardKey.digit3,
  4: PhysicalKeyboardKey.digit4,
  5: PhysicalKeyboardKey.digit5,
  6: PhysicalKeyboardKey.digit6,
  7: PhysicalKeyboardKey.digit7,
  8: PhysicalKeyboardKey.digit8,
  9: PhysicalKeyboardKey.digit9,
};

const _digitLogicalKeys = <int, LogicalKeyboardKey>{
  0: LogicalKeyboardKey.digit0,
  1: LogicalKeyboardKey.digit1,
  2: LogicalKeyboardKey.digit2,
  3: LogicalKeyboardKey.digit3,
  4: LogicalKeyboardKey.digit4,
  5: LogicalKeyboardKey.digit5,
  6: LogicalKeyboardKey.digit6,
  7: LogicalKeyboardKey.digit7,
  8: LogicalKeyboardKey.digit8,
  9: LogicalKeyboardKey.digit9,
};
