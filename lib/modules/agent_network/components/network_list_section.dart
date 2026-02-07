import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/components/network_summary_component.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

class NetworkListSection extends StatefulComponent {
  final List<VideSessionInfo> sessions;
  final bool focused;
  final double listHeight;
  final void Function(String sessionId)? onSessionSelected;
  final void Function(int index)? onSessionDeleted;
  final void Function()? onUpEdge;

  const NetworkListSection({
    required this.sessions,
    this.focused = false,
    this.listHeight = 0,
    this.onSessionSelected,
    this.onSessionDeleted,
    this.onUpEdge,
    super.key,
  });

  @override
  State<NetworkListSection> createState() => _NetworkListSectionState();
}

class _NetworkListSectionState extends State<NetworkListSection> {
  int _selectedNetworkIndex = 0;
  int? _pendingDeleteIndex;
  final _scrollController = ScrollController();

  @override
  void didUpdateComponent(NetworkListSection oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.sessions.isNotEmpty &&
        _selectedNetworkIndex >= component.sessions.length) {
      _selectedNetworkIndex = (component.sessions.length - 1).clamp(
        0,
        component.sessions.length - 1,
      );
    }
    if (component.focused && !oldComponent.focused) {
      setState(() {
        _selectedNetworkIndex = 0;
        _pendingDeleteIndex = null;
      });
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    final networks = component.sessions;
    if (networks.isEmpty) return false;

    if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      setState(() {
        _selectedNetworkIndex++;
        _selectedNetworkIndex = _selectedNetworkIndex.clamp(
          0,
          networks.length - 1,
        );
        _pendingDeleteIndex = null;
      });
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollController.ensureIndexVisible(index: _selectedNetworkIndex * 2);
      });
      return true;
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedNetworkIndex == 0) {
        setState(() {
          _pendingDeleteIndex = null;
        });
        component.onUpEdge?.call();
        return true;
      }
      setState(() {
        _selectedNetworkIndex--;
        _selectedNetworkIndex = _selectedNetworkIndex.clamp(
          0,
          networks.length - 1,
        );
        _pendingDeleteIndex = null;
      });
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollController.ensureIndexVisible(index: _selectedNetworkIndex * 2);
      });
      return true;
    } else if (event.logicalKey == LogicalKey.backspace) {
      if (_pendingDeleteIndex == _selectedNetworkIndex) {
        component.onSessionDeleted?.call(_selectedNetworkIndex);
        setState(() {
          _pendingDeleteIndex = null;
          if (_selectedNetworkIndex >= networks.length - 1) {
            _selectedNetworkIndex = (networks.length - 2).clamp(
              0,
              networks.length - 1,
            );
          }
        });
      } else {
        setState(() {
          _pendingDeleteIndex = _selectedNetworkIndex;
        });
      }
      return true;
    } else if (event.logicalKey == LogicalKey.enter) {
      final network = networks[_selectedNetworkIndex];
      component.onSessionSelected?.call(network.id);
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final networks = component.sessions;

    if (networks.isEmpty) return const SizedBox.shrink();

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          if (!component.focused)
            Center(
              child: Text(
                '↓ ${networks.length} previous conversation${networks.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              ),
            )
          else
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 120),
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      '─── ',
                      style: TextStyle(
                        color: theme.base.outline.withOpacity(
                          TextOpacity.separator,
                        ),
                      ),
                    ),
                    Text(
                      'Previous Conversations',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.secondary,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' (↑↓ ⏎ ⌫⌫) ',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '─────────────────────────────────────────',
                        style: TextStyle(
                          color: theme.base.outline.withOpacity(
                            TextOpacity.separator,
                          ),
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 1),
          if (component.focused)
            SizedBox(
              height: component.listHeight,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 120),
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: ListView(
                    lazy: true,
                    controller: _scrollController,
                    children: [
                      for (int i = 0; i < networks.length; i++) ...[
                        NetworkSummaryComponent(
                          sessionInfo: networks[i],
                          selected: _selectedNetworkIndex == i,
                          showDeleteConfirmation: _pendingDeleteIndex == i,
                        ),
                        if (i < networks.length - 1) SizedBox(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
