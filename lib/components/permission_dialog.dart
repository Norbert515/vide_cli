import 'package:nocterm/nocterm.dart';
import '../modules/permissions/permission_service.dart';

class PermissionDialog extends StatefulComponent {
  final String toolName;
  final String displayAction;
  final String? agentName;
  final String? inferredPattern;
  final Function(bool granted, bool remember) onResponse;

  const PermissionDialog({
    required this.toolName,
    required this.displayAction,
    this.agentName,
    this.inferredPattern,
    required this.onResponse,
    super.key,
  });

  /// Create from permission request
  factory PermissionDialog.fromRequest({
    required PermissionRequest request,
    required Function(bool granted, bool remember) onResponse,
    Key? key,
  }) {
    return PermissionDialog(
      toolName: request.toolName,
      displayAction: request.displayAction,
      inferredPattern: request.inferredPattern,
      onResponse: onResponse,
      key: key,
    );
  }

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  bool _hasResponded = false;
  int _selectedIndex = 0;

  // List of options
  final List<_PermissionOption> _options = [
    _PermissionOption('Allow', granted: true, remember: false),
    _PermissionOption('Allow and remember', granted: true, remember: true),
    _PermissionOption('Deny', granted: false, remember: false),
  ];

  void _handleResponse(_PermissionOption option) {
    if (_hasResponded) return;
    _hasResponded = true;
    component.onResponse(option.granted, option.remember);
  }

  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.grey),
        color: Colors.black,
      ),
      child: KeyboardListener(
        onKeyEvent: (key) {
          if (key == LogicalKey.arrowUp) {
            setState(() {
              _selectedIndex = (_selectedIndex - 1) % _options.length;
              if (_selectedIndex < 0) _selectedIndex = _options.length - 1;
            });
            return true;
          } else if (key == LogicalKey.arrowDown) {
            setState(() {
              _selectedIndex = (_selectedIndex + 1) % _options.length;
            });
            return true;
          } else if (key == LogicalKey.enter) {
            _handleResponse(_options[_selectedIndex]);
            return true;
          } else if (key == LogicalKey.escape) {
            _handleResponse(_options[2]); // Deny
            return true;
          }
          return false;
        },
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Permission Request',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),

            // Agent name (if aggregated)
            if (component.agentName != null)
              Text(
                'Agent: ${component.agentName}',
                style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
              ),

            // Tool and action
            Text(
              'Tool: ${component.toolName}',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(component.displayAction, style: TextStyle(color: Colors.white)),

            // Show inferred pattern if "remember" would be used
            if (component.inferredPattern != null)
              Text('Pattern: ${component.inferredPattern}', style: TextStyle(color: Colors.yellow)),

            Divider(color: Colors.grey),

            // List of options
            for (int i = 0; i < _options.length; i++) _buildListItem(i, _options[i]),
          ],
        ),
      ),
    );
  }

  Component _buildListItem(int index, _PermissionOption option) {
    final isSelected = index == _selectedIndex;
    final color = option.granted ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            isSelected ? '→ ' : '  ',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            option.label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionOption {
  final String label;
  final bool granted;
  final bool remember;

  _PermissionOption(this.label, {required this.granted, required this.remember});
}
