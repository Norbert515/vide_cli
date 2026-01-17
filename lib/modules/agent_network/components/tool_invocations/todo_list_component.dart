import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// Reusable component for displaying a todo list.
/// Shows tasks with status icons and color coding.
class TodoListComponent extends StatelessComponent {
  final List<Map<String, dynamic>> todos;

  const TodoListComponent({required this.todos, super.key});

  @override
  Component build(BuildContext context) {
    // Hide if empty
    if (todos.isEmpty) {
      return SizedBox();
    }

    // Hide if all todos are completed
    final allCompleted = todos.every((todo) => todo['status'] == 'completed');
    if (allCompleted) {
      return SizedBox();
    }

    // Hide if stale: no active work (no in_progress items)
    // This handles: agent delegated to sub-agents, agent is idle, stale pending lists
    final hasActiveWork = todos.any((todo) => todo['status'] == 'in_progress');
    if (!hasActiveWork) {
      return SizedBox();
    }

    final theme = VideTheme.of(context);

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('●', style: TextStyle(color: theme.status.inProgress)),
              SizedBox(width: 1),
              Text('Tasks', style: TextStyle(color: theme.base.onSurface)),
              Text(
                ' (${todos.length} ${todos.length == 1 ? 'item' : 'items'})',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            ],
          ),

          // Todo list
          if (todos.isNotEmpty)
            Container(
              padding: EdgeInsets.only(left: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final todo in todos) _buildTodoItem(context, todo),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Component _buildTodoItem(BuildContext context, Map<String, dynamic> todo) {
    final content = todo['content']?.toString() ?? '';
    final status = todo['status']?.toString() ?? 'pending';
    final icon = _getStatusIcon(status);
    final color = _getItemColor(context, status);

    return Row(
      children: [
        Text(icon, style: TextStyle(color: color)),
        SizedBox(width: 1),
        Expanded(
          child: Text(
            content,
            style: TextStyle(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return '✓';
      case 'in_progress':
        return '●';
      case 'pending':
      default:
        return '○';
    }
  }

  Color _getItemColor(BuildContext context, String status) {
    final theme = VideTheme.of(context);
    switch (status) {
      case 'completed':
        return theme.status.completed;
      case 'in_progress':
        return theme.status.inProgress;
      case 'pending':
      default:
        return theme.base.onSurface.withOpacity(TextOpacity.secondary);
    }
  }
}
