import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/haiku/haiku_providers.dart';

/// Displays session token usage in the bottom right corner
class SessionTokenCounter extends StatelessComponent {
  const SessionTokenCounter({super.key});

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }

  @override
  Component build(BuildContext context) {
    final usage = context.watch(sessionTokenUsageProvider);

    // Don't show if no tokens used yet
    if (usage.totalTokens == 0) return SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '↑${_formatTokens(usage.inputTokens)} ↓${_formatTokens(usage.outputTokens)}',
          style: TextStyle(color: Colors.white.withOpacity(0.3)),
        ),
      ],
    );
  }
}
