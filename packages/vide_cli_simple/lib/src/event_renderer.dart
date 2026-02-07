import 'dart:io';

import 'package:vide_core/vide_core.dart';

/// ANSI color codes for terminal output.
class _Colors {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
  static const cyan = '\x1B[36m';
  static const yellow = '\x1B[33m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const magenta = '\x1B[35m';
  static const blue = '\x1B[34m';
}

/// Per-agent streaming state.
class _AgentState {
  String? currentEventId;
  bool isStreaming = false;
}

/// Renders [VideEvent]s to the terminal with multi-agent support.
///
/// Each agent gets a distinct color and prefix for easy identification.
/// When agents produce output simultaneously, context switches are clearly marked.
class EventRenderer {
  /// Whether to use colors in output.
  final bool useColors;

  /// Per-agent state tracking.
  final Map<String, _AgentState> _agentStates = {};

  /// Currently active agent (the one whose output we're streaming).
  String? _activeAgentId;

  /// Colors assigned to agents (cycles through available colors).
  final Map<String, String> _agentColors = {};
  int _colorIndex = 0;

  static const _availableColors = [
    _Colors.cyan,
    _Colors.green,
    _Colors.yellow,
    _Colors.magenta,
    _Colors.blue,
  ];

  EventRenderer({this.useColors = true});

  String _color(String code) => useColors ? code : '';

  String _getAgentColor(String agentId) {
    return _agentColors.putIfAbsent(agentId, () {
      final color = _availableColors[_colorIndex % _availableColors.length];
      _colorIndex++;
      return color;
    });
  }

  _AgentState _getAgentState(String agentId) {
    return _agentStates.putIfAbsent(agentId, () => _AgentState());
  }

  /// Render an event to stdout.
  void render(VideEvent event) {
    switch (event) {
      case MessageEvent e:
        _renderMessage(e);
      case ToolUseEvent e:
        _renderToolUse(e);
      case ToolResultEvent e:
        _renderToolResult(e);
      case StatusEvent e:
        _renderStatus(e);
      case TurnCompleteEvent e:
        _renderTurnComplete(e);
      case AgentSpawnedEvent e:
        _renderAgentSpawned(e);
      case AgentTerminatedEvent e:
        _renderAgentTerminated(e);
      case PermissionRequestEvent e:
        _renderPermissionRequest(e);
      case AskUserQuestionEvent e:
        _renderAskUserQuestion(e);
      case ErrorEvent e:
        _renderError(e);
      case TaskNameChangedEvent _:
      case ConnectedEvent _:
      case HistoryEvent _:
      case AbortedEvent _:
      case CommandResultEvent _:
      case PermissionResolvedEvent _:
      case UnknownEvent _:
        // Internal/transport events, no rendering needed
        break;
    }
  }

  void _renderAskUserQuestion(AskUserQuestionEvent e) {
    _finishAllStreaming();
    stdout.writeln('');
    stdout.writeln(
      '\x1B[33m❓ AskUserQuestion (${e.questions.length} questions)\x1B[0m',
    );
    for (var i = 0; i < e.questions.length; i++) {
      final q = e.questions[i];
      stdout.writeln('  Q${i + 1}: ${q.question}');
      for (var j = 0; j < q.options.length; j++) {
        stdout.writeln('    ${j + 1}. ${q.options[j].label}');
      }
    }
  }

  void _renderMessage(MessageEvent e) {
    if (e.role == 'assistant') {
      final agentState = _getAgentState(e.agentId);

      // Check if we need to switch agents
      if (_activeAgentId != null && _activeAgentId != e.agentId) {
        // Finish the previous agent's streaming
        _finishStreamingForAgent(_activeAgentId!);
        // Show context switch
        _showAgentSwitch(e);
      } else if (_activeAgentId == null && e.content.isNotEmpty) {
        // First message or resuming - show agent header if not main
        if (e.agentType != 'main') {
          _showAgentHeader(e);
        }
      }

      // Stream text content
      if (e.content.isNotEmpty) {
        stdout.write(e.content);
        agentState.isStreaming = true;
        agentState.currentEventId = e.eventId;
        _activeAgentId = e.agentId;
      }

      // End of message
      if (!e.isPartial && agentState.isStreaming) {
        stdout.writeln();
        agentState.isStreaming = false;
        agentState.currentEventId = null;
      }
    } else if (e.role == 'user') {
      _finishAllStreaming();
      stdout.writeln(
        '${_color(_Colors.dim)}[User: ${e.content}]${_color(_Colors.reset)}',
      );
    }
  }

  void _showAgentHeader(VideEvent e) {
    final color = _getAgentColor(e.agentId);
    final name = e.agentName ?? e.agentType;
    stdout.writeln();
    stdout.writeln(
      '${_color(color)}${_color(_Colors.bold)}━━━ $name ━━━${_color(_Colors.reset)}',
    );
  }

  void _showAgentSwitch(VideEvent e) {
    final color = _getAgentColor(e.agentId);
    final name = e.agentName ?? e.agentType;
    stdout.writeln();
    stdout.writeln(
      '${_color(color)}${_color(_Colors.bold)}━━━ $name ━━━${_color(_Colors.reset)}',
    );
  }

  void _renderToolUse(ToolUseEvent e) {
    _handleAgentContextSwitch(e);
    final color = _getAgentColor(e.agentId);
    final prefix = _agentPrefix(e);
    stdout.writeln(
      '${_color(color)}$prefix[Tool: ${e.toolName}]${_color(_Colors.reset)}',
    );
  }

  void _renderToolResult(ToolResultEvent e) {
    if (e.isError) {
      final prefix = _agentPrefix(e);
      stdout.writeln(
        '${_color(_Colors.red)}$prefix[Tool Error: ${_truncate(e.result, 100)}]${_color(_Colors.reset)}',
      );
    }
    // Don't print successful tool results by default - too verbose
  }

  // ignore: unused_element
  void _renderStatus(StatusEvent e) {
    // Status events are typically too verbose for CLI output.
    // Keep method for potential future use but don't render anything.
  }

  void _renderTurnComplete(TurnCompleteEvent e) {
    _finishStreamingForAgent(e.agentId);
    final color = _getAgentColor(e.agentId);
    final prefix = _agentPrefix(e);

    // Show token usage if available
    final tokenInfo = e.totalCostUsd > 0
        ? ' (${e.currentContextWindowTokens} ctx, \$${e.totalCostUsd.toStringAsFixed(4)})'
        : '';
    stdout.writeln(
      '${_color(color)}${_color(_Colors.dim)}$prefix--- ${e.reason}$tokenInfo ---${_color(_Colors.reset)}',
    );
    stdout.writeln();

    // Clear active agent if this was it
    if (_activeAgentId == e.agentId) {
      _activeAgentId = null;
    }
  }

  void _renderAgentSpawned(AgentSpawnedEvent e) {
    _finishAllStreaming();
    final color = _getAgentColor(e.agentId);
    stdout.writeln(
      '${_color(color)}${_color(_Colors.bold)}[+ Agent: ${e.agentName ?? e.agentId}]${_color(_Colors.reset)}',
    );
  }

  void _renderAgentTerminated(AgentTerminatedEvent e) {
    _finishAllStreaming();
    final color = _getAgentColor(e.agentId);
    stdout.writeln(
      '${_color(color)}${_color(_Colors.dim)}[- Agent: ${e.agentName ?? e.agentId}]${_color(_Colors.reset)}',
    );

    // Clean up state
    _agentStates.remove(e.agentId);
    if (_activeAgentId == e.agentId) {
      _activeAgentId = null;
    }
  }

  void _renderPermissionRequest(PermissionRequestEvent e) {
    _finishAllStreaming();
    final color = _getAgentColor(e.agentId);
    final name = e.agentName ?? e.agentType;

    stdout.writeln();
    stdout.writeln(
      '${_color(_Colors.magenta)}╔══════════════════════════════════════════════════════════════╗${_color(_Colors.reset)}',
    );
    stdout.writeln(
      '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  ${_color(color)}Permission Required${_color(_Colors.reset)} (${name})',
    );
    stdout.writeln(
      '${_color(_Colors.magenta)}╠══════════════════════════════════════════════════════════════╣${_color(_Colors.reset)}',
    );
    stdout.writeln(
      '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  Tool: ${e.toolName}',
    );

    // Show relevant input parameters
    final input = e.toolInput;
    if (input.containsKey('command')) {
      stdout.writeln(
        '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  Command: ${_truncate(input['command'].toString(), 50)}',
      );
    }
    if (input.containsKey('file_path')) {
      stdout.writeln(
        '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  File: ${input['file_path']}',
      );
    }
    if (input.containsKey('url')) {
      stdout.writeln(
        '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  URL: ${input['url']}',
      );
    }

    stdout.writeln(
      '${_color(_Colors.magenta)}╠══════════════════════════════════════════════════════════════╣${_color(_Colors.reset)}',
    );
    stdout.writeln(
      '${_color(_Colors.magenta)}║${_color(_Colors.reset)}  Allow? [y/n]: ',
    );
    stdout.writeln(
      '${_color(_Colors.magenta)}╚══════════════════════════════════════════════════════════════╝${_color(_Colors.reset)}',
    );
  }

  void _renderError(ErrorEvent e) {
    _finishAllStreaming();
    final prefix = _agentPrefix(e);
    stdout.writeln(
      '${_color(_Colors.red)}$prefix[Error: ${e.message}]${_color(_Colors.reset)}',
    );
  }

  void _handleAgentContextSwitch(VideEvent e) {
    if (_activeAgentId != null && _activeAgentId != e.agentId) {
      _finishStreamingForAgent(_activeAgentId!);
      if (e.agentType != 'main') {
        _showAgentSwitch(e);
      }
    }
    _activeAgentId = e.agentId;
  }

  void _finishStreamingForAgent(String agentId) {
    final state = _agentStates[agentId];
    if (state != null && state.isStreaming) {
      stdout.writeln();
      state.isStreaming = false;
      state.currentEventId = null;
    }
  }

  void _finishAllStreaming() {
    for (final entry in _agentStates.entries) {
      if (entry.value.isStreaming) {
        stdout.writeln();
        entry.value.isStreaming = false;
        entry.value.currentEventId = null;
      }
    }
    _activeAgentId = null;
  }

  String _agentPrefix(VideEvent e) {
    if (e.agentType == 'main') return '';
    final color = _getAgentColor(e.agentId);
    final name = e.agentName ?? e.agentType;
    return '${_color(color)}[$name]${_color(_Colors.reset)} ';
  }

  String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength)}...';
  }
}
