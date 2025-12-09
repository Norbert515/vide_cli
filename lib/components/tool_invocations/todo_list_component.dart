import 'package:nocterm/nocterm.dart';
import 'package:parott/constants/text_opacity.dart';

/// Reusable component for displaying a todo list.
/// Shows tasks with status icons and color coding.
class TodoListComponent extends StatelessComponent {
  final List<Map<String, dynamic>> todos;

  const TodoListComponent({
    required this.todos,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    // Hide the component if all todos are completed
    final allCompleted = todos.isNotEmpty && todos.every((todo) => todo['status'] == 'completed');
    if (allCompleted) {
      return SizedBox();
    }

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('●', style: TextStyle(color: Color(0xFFE5C07B))),
              SizedBox(width: 1),
              Text('Tasks', style: TextStyle(color: Colors.white)),
              Text(
                ' (${todos.length} ${todos.length == 1 ? 'item' : 'items'})',
                style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
              ),
            ],
          ),

          // Todo list
          if (todos.isNotEmpty)
            Container(
              padding: EdgeInsets.only(left: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final todo in todos) _buildTodoItem(todo)],
              ),
            ),
        ],
      ),
    );
  }

  Component _buildTodoItem(Map<String, dynamic> todo) {
    final content = todo['content']?.toString() ?? '';
    final status = todo['status']?.toString() ?? 'pending';
    final icon = _getStatusIcon(status);
    final color = _getItemColor(status);

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

  Color _getItemColor(String status) {
    switch (status) {
      case 'completed':
        return Color(0xFF98C379); // Green
      case 'in_progress':
        return Color(0xFFE5C07B); // Yellow/orange
      case 'pending':
      default:
        return Colors.white.withOpacity(TextOpacity.secondary);
    }
  }
}
