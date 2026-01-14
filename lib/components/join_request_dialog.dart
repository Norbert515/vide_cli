import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';

/// Dialog for responding to a remote client join request.
class JoinRequestDialog extends StatefulComponent {
  /// The join request from a remote client.
  final JoinRequest request;

  /// Callback when user responds to the request.
  final void Function(JoinResponse response) onResponse;

  const JoinRequestDialog({
    required this.request,
    required this.onResponse,
    super.key,
  });

  @override
  State<JoinRequestDialog> createState() => _JoinRequestDialogState();
}

class _JoinRequestDialogState extends State<JoinRequestDialog> {
  int _selectedIndex = 0;
  bool _hasResponded = false;

  static const _options = [
    _JoinOption('Allow', JoinResponse.allow, Colors.green),
    _JoinOption('Allow (Read-Only)', JoinResponse.allowReadOnly, Colors.cyan),
    _JoinOption('Deny', JoinResponse.deny, Colors.red),
  ];

  void _handleResponse(_JoinOption option) {
    if (_hasResponded) return;
    _hasResponded = true;
    component.onResponse(option.response);
  }

  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.yellow),
        color: Colors.black,
      ),
      child: KeyboardListener(
        onKeyEvent: (key) {
          if (_hasResponded) return true;

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
            // ESC denies the request
            _handleResponse(_options.last);
            return true;
          }
          return false;
        },
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with warning icon
            Text(
              'Remote Connection Request',
              style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),

            Divider(color: Colors.grey),

            // Request details
            Text(
              'A remote client wants to connect:',
              style: TextStyle(color: Colors.white),
            ),

            SizedBox(height: 1),

            // Client address
            Row(
              children: [
                Text('Address: ', style: TextStyle(color: Colors.grey)),
                Text(
                  component.request.remoteAddress,
                  style: TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            SizedBox(height: 1),

            Divider(color: Colors.grey),

            // Options
            for (int i = 0; i < _options.length; i++)
              _buildOptionRow(i, _options[i]),

            SizedBox(height: 1),

            Text(
              'ESC to deny',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildOptionRow(int index, _JoinOption option) {
    final isSelected = index == _selectedIndex;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            isSelected ? '-> ' : '  ',
            style: TextStyle(color: option.color, fontWeight: FontWeight.bold),
          ),
          Text(
            option.label,
            style: TextStyle(
              color: isSelected ? option.color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinOption {
  final String label;
  final JoinResponse response;
  final Color color;

  const _JoinOption(this.label, this.response, this.color);
}
