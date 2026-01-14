import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';

import '../services/session_service.dart';

/// Dialog for enabling/disabling remote access and viewing connected clients.
///
/// This dialog is purely a display component - key handling is done by the parent.
class RemoteAccessDialog extends StatelessComponent {
  /// The current remote access state.
  final RemoteAccessState state;

  /// Currently selected option index.
  final int selectedIndex;

  const RemoteAccessDialog({
    required this.state,
    required this.selectedIndex,
    super.key,
  });

  List<_DialogOption> get _options {
    if (state.isEnabled) {
      return [
        _DialogOption('Close', isDestructive: false),
        _DialogOption('Disable Remote Access', isDestructive: true),
      ];
    } else {
      return [
        _DialogOption('Enable Remote Access', isDestructive: false),
        _DialogOption('Cancel', isDestructive: false),
      ];
    }
  }

  @override
  Component build(BuildContext context) {
    final options = _options;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.grey),
        color: Colors.black,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Remote Access',
            style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
          ),

          Divider(color: Colors.grey),

          if (state.isEnabled && state.serverInfo != null) ...[
            // Server info
            Text(
              'Server running at:',
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              '${state.serverInfo!.address}:${state.serverInfo!.port}',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 1),

            // Connected clients
            Text(
              'Connected clients: ${state.clients.length}',
              style: TextStyle(color: Colors.grey),
            ),
            if (state.clients.isNotEmpty)
              for (final client in state.clients) _buildClientRow(client),

            Divider(color: Colors.grey),
          ] else ...[
            // Description when disabled
            Text(
              'Allow remote clients to connect to this session.',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'You can approve or deny each connection request.',
              style: TextStyle(color: Colors.grey),
            ),

            Divider(color: Colors.grey),
          ],

          for (int i = 0; i < options.length; i++)
            _buildOptionRow(i, options[i]),

          SizedBox(height: 1),

          Text(
            'Press ESC to close',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Component _buildClientRow(ConnectedClient client) {
    final permissionLabel = client.permission.name;
    final address = client.remoteAddress ?? 'unknown';

    return Container(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        '- $address ($permissionLabel)',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Component _buildOptionRow(int index, _DialogOption option) {
    final isSelected = index == selectedIndex;
    final color = option.isDestructive ? Colors.red : Colors.green;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            isSelected ? '-> ' : '   ',
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

class _DialogOption {
  final String label;
  final bool isDestructive;

  _DialogOption(this.label, {required this.isDestructive});
}
