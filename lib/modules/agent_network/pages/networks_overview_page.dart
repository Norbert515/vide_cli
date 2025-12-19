import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:claude_api/claude_api.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_list_page.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/components/attachment_text_field.dart';
import 'package:vide_cli/modules/haiku/haiku_service.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';
import 'package:vide_cli/modules/haiku/prompts/loading_words_prompt.dart';
import 'package:vide_cli/modules/haiku/prompts/placeholder_prompt.dart';
import 'package:vide_cli/utils/project_detector.dart';
import 'package:path/path.dart' as path;

class NetworksOverviewPage extends StatefulComponent {
  const NetworksOverviewPage({super.key});

  @override
  State<NetworksOverviewPage> createState() => _NetworksOverviewPageState();
}

class _NetworksOverviewPageState extends State<NetworksOverviewPage> {
  ProjectType? projectType;

  // Placeholder animation state
  Timer? _placeholderTimer;
  bool _isLoadingPlaceholder = true;
  bool _isTypingPlaceholder = false;
  String _fullPlaceholder = '';
  String _displayedPlaceholder = '';
  int _typingIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProjectInfo();
    _generateStartupContent();
  }

  void _startTypingAnimation(String text) {
    _placeholderTimer?.cancel();
    _fullPlaceholder = text;
    _typingIndex = 0;
    _displayedPlaceholder = '';
    _isTypingPlaceholder = true;

    _placeholderTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted && _typingIndex < _fullPlaceholder.length) {
        setState(() {
          _typingIndex++;
          _displayedPlaceholder = _fullPlaceholder.substring(0, _typingIndex);
        });
      } else {
        _placeholderTimer?.cancel();
        setState(() {
          _isTypingPlaceholder = false;
          _displayedPlaceholder = _fullPlaceholder;
        });
      }
    });
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProjectInfo() async {
    final currentDir = Directory.current.path;
    final detectedType = ProjectDetector.detectProjectType(currentDir);

    if (mounted) {
      setState(() {
        projectType = detectedType;
      });
    }
  }

  /// Generate startup content using HaikuService
  void _generateStartupContent() {
    final now = DateTime.now();

    // Pre-generate loading words for first message
    HaikuService.invokeForList(
      systemPrompt: LoadingWordsPrompt.build(now),
      userMessage: 'Generate loading words for: "Starting a new coding session"',
      delay: Duration.zero, // No delay on startup
    ).then((words) {
      if (mounted && words != null) {
        context.read(loadingWordsProvider.notifier).state = words;
      }
    });

    // Generate dynamic placeholder text
    HaikuService.invoke(
      systemPrompt: PlaceholderPrompt.build(now),
      userMessage: 'Generate placeholder text',
      delay: Duration.zero,
    ).then((placeholder) {
      if (mounted) {
        setState(() {
          _isLoadingPlaceholder = false;
        });
        String text = placeholder?.trim() ?? 'Describe your goal (you can attach images)';

        // Validate: handle verbose multi-line responses
        if (text.contains('\n') || text.length > 50) {
          // Multi-line or too long - try to extract just the placeholder
          final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          // Look for a short line that looks like a placeholder (not explanation text)
          String? shortLine;
          for (final line in lines) {
            // Skip lines that look like explanations
            if (line.startsWith('Here') ||
                line.startsWith('Alright') ||
                line.contains(':') ||
                line.startsWith('Pick') ||
                line.startsWith('I')) continue;
            // Clean up markdown and list markers
            final cleaned =
                line.replaceAll(RegExp(r'^[\*\-\d\.\)]+\s*'), '').replaceAll('**', '').trim();
            if (cleaned.length >= 3 && cleaned.length <= 45) {
              shortLine = cleaned;
              break;
            }
          }
          text = shortLine ?? 'Describe your goal (you can attach images)';
        }

        // Final safety: if still too long, use fallback
        if (text.length > 50) {
          text = 'Describe your goal (you can attach images)';
        }

        context.read(placeholderTextProvider.notifier).state = text;
        _startTypingAnimation(text);
      }
    });
  }

  void _handleSubmit(Message message) async {
    // Start a new agent network with the full message (preserves attachments)
    final network = await context.read(agentNetworkManagerProvider.notifier).startNew(message);

    // Update the networks list
    context.read(agentNetworksStateNotifierProvider.notifier).upsertNetwork(network);

    // Navigate to the execution page
    await NetworkExecutionPage.push(context, network.id);
  }

  @override
  Component build(BuildContext context) {
    // Get current directory name
    final currentDir = Directory.current.path;
    final dirName = path.basename(currentDir);

    // Get placeholder - empty while loading, then type in the text when ready
    final String placeholder;
    if (_isLoadingPlaceholder) {
      placeholder = '';
    } else if (_isTypingPlaceholder) {
      placeholder = _displayedPlaceholder;
    } else {
      placeholder = _displayedPlaceholder.isNotEmpty
          ? _displayedPlaceholder
          : (context.watch(placeholderTextProvider) ?? 'Describe your goal (you can attach images)');
    }

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.tab) {
          NetworksListPage.push(context);
          return true;
        }
        return false;
      },
      child: Center(
        child: Container(
          padding: EdgeInsets.all(2),
          constraints: BoxConstraints(maxWidth: 120, maxHeight: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dirName,
                style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 1),
              // Project info badge
              if (projectType != null) ...[
                _ProjectTypeBadge(projectType: projectType!),
                const SizedBox(height: 1),
              ],
              Container(
                child: AttachmentTextField(
                  focused: true,
                  placeholder: placeholder,
                  onSubmit: _handleSubmit,
                ),
                padding: EdgeInsets.all(1),
              ),
              const SizedBox(height: 2),
              Text('Tab: past networks & settings | Enter: start', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Project type badge component
class _ProjectTypeBadge extends StatelessComponent {
  const _ProjectTypeBadge({required this.projectType});

  final ProjectType projectType;

  @override
  Component build(BuildContext context) {
    String label;
    Color bgColor;

    switch (projectType) {
      case ProjectType.flutter:
        label = 'Flutter';
        bgColor = Color(0xFF02569B); // Flutter blue
        break;
      case ProjectType.dart:
        label = 'Dart';
        bgColor = Color(0xFF0175C2); // Dart blue
        break;
      case ProjectType.nocterm:
        label = 'Nocterm';
        bgColor = Color(0xFF9B30FF); // Purple
        break;
      case ProjectType.unknown:
        label = 'Unknown';
        bgColor = Colors.grey;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: bgColor),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
