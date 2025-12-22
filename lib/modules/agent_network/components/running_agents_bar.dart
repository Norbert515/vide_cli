import 'dart:async';
import 'package:claude_api/claude_api.dart';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/models/agent_metadata.dart';
import 'package:vide_cli/modules/agent_network/models/agent_status.dart';
import 'package:vide_cli/modules/agent_network/service/claude_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_status_manager.dart';

class RunningAgentsBar extends StatelessComponent {
  const RunningAgentsBar({super.key, required this.agents, this.selectedIndex = 0});

  final List<AgentMetadata> agents;
  final int selectedIndex;

  /// Calculate max log line width based on number of agents
  /// More agents = shorter lines so they fit
  int _getMaxLogWidth(int agentCount) {
    if (agentCount <= 2) return 45;
    if (agentCount == 3) return 40;
    if (agentCount == 4) return 32;
    if (agentCount == 5) return 26;
    return 22; // 6+ agents
  }

  @override
  Component build(BuildContext context) {
    final maxLogWidth = _getMaxLogWidth(agents.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align all columns at top
      children: [
        for (int i = 0; i < agents.length; i++)
          _AgentColumn(
            agent: agents[i],
            isSelected: i == selectedIndex,
            maxLogWidth: maxLogWidth,
          ),
      ],
    );
  }
}

/// A single agent column: badge on top, tool log directly below
class _AgentColumn extends StatefulComponent {
  final AgentMetadata agent;
  final bool isSelected;
  final int maxLogWidth;

  const _AgentColumn({
    required this.agent,
    required this.isSelected,
    required this.maxLogWidth,
  });

  @override
  State<_AgentColumn> createState() => _AgentColumnState();
}

class _AgentColumnState extends State<_AgentColumn> {
  static const _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  static const _maxTotalLines = 3; // Total lines under badge (task name + tool logs)

  /// Tools to skip entirely in the log (noise)
  static const _skipTools = {'TodoWrite', 'mcp__vide-task-management__setTaskName', 'mcp__vide-task-management__setAgentTaskName'};

  // Static storage for typing animation state per agent (persists across tab switches)
  static final Map<String, _TypingState> _typingStates = {};

  Timer? _spinnerTimer;
  int _spinnerIndex = 0;

  // Typing animation timer (per-widget, but state is stored in static map)
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length);
    });
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    _typingTimer?.cancel();
    // Clean up typing state to prevent memory leak when agent terminates
    _typingStates.remove(component.agent.id);
    super.dispose();
  }

  _TypingState _getTypingState() {
    final agentId = component.agent.id;
    return _typingStates.putIfAbsent(agentId, () => _TypingState());
  }

  void _maybeStartTypingAnimation(String? taskName) {
    final state = _getTypingState();

    if (taskName == null || taskName.isEmpty) {
      state.displayedText = '';
      state.lastTaskName = null;
      return;
    }

    // If animation already complete for this task name, nothing to do
    if (taskName == state.lastTaskName && state.typingIndex >= taskName.length) {
      return;
    }

    // If same task name and animation in progress, continue it
    if (taskName == state.lastTaskName) {
      // Resume animation from where it left off
      _typingTimer?.cancel();
      _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted && state.typingIndex < taskName.length) {
          setState(() {
            state.typingIndex++;
            state.displayedText = taskName.substring(0, state.typingIndex);
          });
        } else {
          _typingTimer?.cancel();
        }
      });
      return;
    }

    // New task name - start fresh animation
    _typingTimer?.cancel();
    state.lastTaskName = taskName;
    state.typingIndex = 0;
    state.displayedText = '';

    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted && state.typingIndex < taskName.length) {
        setState(() {
          state.typingIndex++;
          state.displayedText = taskName.substring(0, state.typingIndex);
        });
      } else {
        _typingTimer?.cancel();
      }
    });
  }

  String _getStatusIndicator(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => _spinnerFrames[_spinnerIndex],
      AgentStatus.waitingForAgent => '…',
      AgentStatus.waitingForUser => '?',
      AgentStatus.idle => '✓',
    };
  }

  Color _getIndicatorColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => Colors.cyan,
      AgentStatus.waitingForAgent => Colors.yellow,
      AgentStatus.waitingForUser => Colors.magenta,
      AgentStatus.idle => Colors.green,
    };
  }

  Color _getIndicatorTextColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.waitingForAgent => Colors.black,
      _ => Colors.white,
    };
  }

  AgentStatus _inferActualStatus(AgentStatus explicitStatus, Conversation? conversation) {
    if (conversation == null) return explicitStatus;
    if (conversation.isProcessing) return AgentStatus.working;
    if (conversation.state == ConversationState.idle && explicitStatus == AgentStatus.working) {
      return AgentStatus.idle;
    }
    return explicitStatus;
  }

  List<ToolUseResponse> _getRecentToolUses(Conversation conversation, int count) {
    final toolUses = <ToolUseResponse>[];
    for (final message in conversation.messages.reversed) {
      if (message.role == MessageRole.assistant) {
        for (final response in message.responses.reversed) {
          if (response is ToolUseResponse) {
            // Skip tools we want to filter out
            if (_skipTools.contains(response.toolName)) continue;
            toolUses.add(response);
            if (toolUses.length >= count) return toolUses;
          }
        }
      }
    }
    return toolUses;
  }

  /// Translate MCP tool names to friendly labels
  String _translateToolName(String name) {
    // Vide agent tools
    if (name == 'mcp__vide-agent__setAgentStatus') return 'Status';
    if (name == 'mcp__vide-agent__spawnAgent') return 'Spawn';
    if (name == 'mcp__vide-agent__sendMessageToAgent') return 'Message';
    if (name == 'mcp__vide-agent__terminateAgent') return 'Terminate';
    // Vide memory tools
    if (name == 'mcp__vide-memory__memorySave') return 'Save';
    if (name == 'mcp__vide-memory__memoryRetrieve') return 'Recall';
    if (name == 'mcp__vide-memory__memoryList') return 'ListMemory';
    // Git tools
    if (name.startsWith('mcp__vide-git__')) return name.replaceFirst('mcp__vide-git__', '');
    // Dart tools
    if (name.startsWith('mcp__dart__')) return name.replaceFirst('mcp__dart__', '');
    // Generic MCP prefix removal
    if (name.startsWith('mcp__')) {
      final parts = name.split('__');
      return parts.length > 1 ? parts.last : name;
    }
    return name;
  }

  String? _formatToolUse(ToolUseResponse toolUse) {
    final name = toolUse.toolName;

    // Skip noisy tools
    if (_skipTools.contains(name)) return null;

    final params = toolUse.parameters;
    final friendlyName = _translateToolName(name);

    String? paramValue;
    if (params.containsKey('query')) {
      paramValue = params['query'] as String;
    } else if (params.containsKey('pattern')) {
      paramValue = params['pattern'] as String;
    } else if (params.containsKey('file_path')) {
      paramValue = (params['file_path'] as String).split('/').last;
    } else if (params.containsKey('command')) {
      paramValue = params['command'] as String;
    } else if (params.containsKey('url')) {
      final uri = Uri.tryParse(params['url'] as String);
      paramValue = uri?.host ?? params['url'] as String;
    } else if (params.containsKey('prompt')) {
      paramValue = params['prompt'] as String;
    } else if (params.containsKey('message')) {
      paramValue = params['message'] as String;
    } else if (params.containsKey('agentType')) {
      // For spawn, show agent type
      paramValue = params['agentType'] as String;
    } else if (params.containsKey('status')) {
      // For status updates
      paramValue = params['status'] as String;
    } else if (params.containsKey('key')) {
      // For memory operations
      paramValue = params['key'] as String;
    }

    String result = paramValue != null ? '$friendlyName("$paramValue")' : friendlyName;
    final maxWidth = component.maxLogWidth;
    if (result.length > maxWidth) {
      return '${result.substring(0, maxWidth - 3)}...';
    }
    return result;
  }

  @override
  Component build(BuildContext context) {
    final explicitStatus = context.watch(agentStatusProvider(component.agent.id));
    final client = context.watch(claudeProvider(component.agent.id));
    final conversation = client?.currentConversation;
    final status = _inferActualStatus(explicitStatus, conversation);

    final indicatorColor = _getIndicatorColor(status);
    final indicatorTextColor = _getIndicatorTextColor(status);
    final statusIndicator = _getStatusIndicator(status);

    // Get task name from agent metadata (set via setAgentTaskName MCP tool)
    final taskName = component.agent.taskName;

    // Trigger typing animation if task name changed (only for sub-agents)
    if (component.agent.type != 'main') {
      _maybeStartTypingAnimation(taskName);
    }

    // Get typing state for this agent
    final typingState = _getTypingState();
    final displayedTaskName = typingState.displayedText;

    // Get tool log (only for sub-agents when not idle)
    // Total lines under badge is capped at 3 (task name counts as 1 if present)
    final showToolLog = status != AgentStatus.idle && component.agent.type != 'main';
    final hasTaskName = displayedTaskName.isNotEmpty && component.agent.type != 'main' && status != AgentStatus.idle;
    final maxToolLogLines = hasTaskName ? _maxTotalLines - 1 : _maxTotalLines;
    final recentToolUses = showToolLog && conversation != null
        ? _getRecentToolUses(conversation, maxToolLogLines)
        : <ToolUseResponse>[];

    return Padding(
      padding: EdgeInsets.only(right: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: indicatorColor),
                child: Text(statusIndicator, style: TextStyle(color: indicatorTextColor)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: Colors.grey),
                child: Text(
                  component.agent.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: component.isSelected ? FontWeight.bold : null,
                    decoration: component.isSelected ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ],
          ),
          // Task name with typing animation (below badge, above tool log, only for sub-agents)
          if (displayedTaskName.isNotEmpty && component.agent.type != 'main' && status != AgentStatus.idle)
            Text(
              displayedTaskName,
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          // Tool log (below task name, only for sub-agents)
          if (recentToolUses.isNotEmpty)
            for (int i = recentToolUses.length - 1; i >= 0; i--)
              Text(
                '${i == 0 ? '↳' : ' '} ${_formatToolUse(recentToolUses[i])}',
                style: TextStyle(
                  color: Colors.white.withOpacity(i == 0 ? 0.7 : 0.5),
                ),
              ),
        ],
      ),
    );
  }
}

/// Stores typing animation state per agent (persists across tab switches)
class _TypingState {
  String? lastTaskName;
  String displayedText = '';
  int typingIndex = 0;
}
