import 'package:nocterm/nocterm.dart';
import '../modules/permissions/permission_service.dart';

class PermissionDialog extends StatefulComponent {
  final String toolName;
  final String displayAction;
  final String? agentName;
  final String? inferredPattern;

  /// Callback with (granted, remember, patternOverride, denyReason)
  /// patternOverride is non-null when user selects a different pattern than the inferred one
  /// denyReason is non-null when user denies with a custom reason
  final Function(
    bool granted,
    bool remember, {
    String? patternOverride,
    String? denyReason,
  })
  onResponse;

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
    required Function(
      bool granted,
      bool remember, {
      String? patternOverride,
      String? denyReason,
    })
    onResponse,
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

  /// Controller for custom deny reason text input
  final _textController = TextEditingController();

  /// Whether the deny option is selected (last option in the list)
  bool get _isDenySelected => _selectedIndex == _options.length - 1;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<_PermissionOption> get _options {
    final options = <_PermissionOption>[
      _PermissionOption('Allow', granted: true, remember: false),
      _PermissionOption('Allow and remember', granted: true, remember: true),
    ];

    // For WebFetch, add an option to allow all WebFetch requests
    if (component.toolName == 'WebFetch' &&
        component.inferredPattern != null &&
        component.inferredPattern != 'WebFetch') {
      options.add(
        _PermissionOption(
          'Allow all WebFetch',
          granted: true,
          remember: true,
          patternOverride: 'WebFetch',
        ),
      );
    }

    options.add(_PermissionOption('Deny', granted: false, remember: false));
    return options;
  }

  void _handleResponse(_PermissionOption option) {
    if (_hasResponded) return;
    _hasResponded = true;

    // If denying with custom reason, pass it along
    String? denyReason;
    if (!option.granted && _textController.text.isNotEmpty) {
      denyReason = _textController.text;
    }

    component.onResponse(
      option.granted,
      option.remember,
      patternOverride: option.patternOverride,
      denyReason: denyReason,
    );
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
          // When deny is selected and text field is active, handle differently
          if (_isDenySelected) {
            if (key == LogicalKey.arrowUp) {
              // Navigate away from deny option
              setState(() {
                _selectedIndex = _selectedIndex - 1;
                if (_selectedIndex < 0) _selectedIndex = _options.length - 1;
              });
              return true;
            } else if (key == LogicalKey.escape) {
              // ESC denies without reason (abort behavior)
              _handleResponse(_options.last);
              return true;
            }
            // Let TextField handle other keys (including enter)
            return false;
          }

          // Normal navigation mode
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
            _handleResponse(_options.last); // Deny
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
                style: TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),

            // Tool and action
            Text(
              'Tool: ${component.toolName}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              component.displayAction,
              style: TextStyle(color: Colors.white),
            ),

            // Show inferred pattern if "remember" would be used
            if (component.inferredPattern != null)
              Text(
                'Pattern: ${component.inferredPattern}',
                style: TextStyle(color: Colors.yellow),
              ),

            Divider(color: Colors.grey),

            // List of options
            for (int i = 0; i < _options.length; i++)
              _buildListItem(i, _options[i]),
          ],
        ),
      ),
    );
  }

  Component _buildListItem(int index, _PermissionOption option) {
    final isSelected = index == _selectedIndex;
    final color = option.granted ? Colors.green : Colors.red;
    final isDenyOption = !option.granted;

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
          // Show inline text field when deny is selected
          if (isDenyOption && isSelected) ...[
            Text(': ', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: TextField(
                controller: _textController,
                focused: true,
                placeholder: 'Reason (optional)',
                onSubmitted: (_) => _handleResponse(option),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionOption {
  final String label;
  final bool granted;
  final bool remember;
  final String? patternOverride;

  _PermissionOption(
    this.label, {
    required this.granted,
    required this.remember,
    this.patternOverride,
  });
}
