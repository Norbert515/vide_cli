import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/models/agent_network.dart';
import 'package:vide_cli/modules/memory/memory_service.dart';
import 'package:vide_cli/modules/agent_network/network_execution_page.dart';
import 'package:vide_cli/modules/agent_network/components/network_summary_component.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/modules/agent_network/service/agent_network_manager.dart';
import 'package:vide_cli/modules/memory/memories_viewer_page.dart';
import 'package:vide_cli/modules/settings/vide_settings_page.dart';
import 'package:path/path.dart' as path;

class NetworksListPage extends StatefulComponent {
  const NetworksListPage({super.key});

  static Future push(BuildContext context) async {
    return Navigator.of(context).push(PageRoute(builder: (context) => NetworksListPage(), settings: RouteSettings()));
  }

  @override
  State<NetworksListPage> createState() => _NetworksListPageState();
}

class _NetworksListPageState extends State<NetworksListPage> {
  int totalMemories = 0;

  @override
  void initState() {
    super.initState();
    _loadMemoryCount();
  }

  Future<void> _loadMemoryCount() async {
    final memoryService = context.read(memoryServiceProvider);
    final allEntries = await memoryService.getAllEntries();
    int count = 0;
    for (final entries in allEntries.values) {
      count += entries.length;
    }
    if (mounted) {
      setState(() {
        totalMemories = count;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final allNetworks = context.watch(agentNetworksStateNotifierProvider).networks;

    // Get current directory name
    final currentDir = Directory.current.path;
    final dirName = path.basename(currentDir);

    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered title with underline
          Text(
            dirName,
            style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 1),
          // Memory and Settings row
          Focusable(
            focused: true,
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKey.keyV) {
                MemoriesViewerPage.push(context);
                return true;
              }
              if (event.logicalKey == LogicalKey.keyS) {
                VideSettingsPage.push(context);
                return true;
              }
              return false;
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MemoryBadge(count: totalMemories),
                SizedBox(width: 2),
                _SettingsBadge(),
              ],
            ),
          ),
          SizedBox(height: 1),
          // Help text
          Text(
            'Esc: home | Backspace×2: delete | V: memories | S: settings',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 2),
          Expanded(child: _NetworksListContent(networks: allNetworks)),
          SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _NetworksListContent extends StatefulComponent {
  const _NetworksListContent({required this.networks});

  final List<AgentNetwork> networks;

  @override
  State<_NetworksListContent> createState() => _NetworksListContentState();
}

class _NetworksListContentState extends State<_NetworksListContent> {
  int selectedIndex = 0;
  int? pendingDeleteIndex;
  final scrollController = ScrollController();

  @override
  void didUpdateComponent(_NetworksListContent oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Clamp selection if list length changed
    if (component.networks.isNotEmpty && selectedIndex >= component.networks.length) {
      selectedIndex = (component.networks.length - 1).clamp(0, component.networks.length - 1);
    }
  }

  @override
  Component build(BuildContext context) {
    if (component.networks.isEmpty) {
      return Center(
        child: Text('No networks yet. Press Esc to create one.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowDown || event.logicalKey == LogicalKey.keyJ) {
          setState(() {
            selectedIndex++;
            selectedIndex = selectedIndex.clamp(0, component.networks.length - 1);
            pendingDeleteIndex = null;
            scrollController.ensureIndexVisible(index: selectedIndex);
          });
          return true;
        } else if (event.logicalKey == LogicalKey.arrowUp || event.logicalKey == LogicalKey.keyK) {
          setState(() {
            selectedIndex--;
            selectedIndex = selectedIndex.clamp(0, component.networks.length - 1);
            pendingDeleteIndex = null;
            scrollController.ensureIndexVisible(index: selectedIndex);
          });
          return true;
        } else if (event.logicalKey == LogicalKey.backspace) {
          if (pendingDeleteIndex == selectedIndex) {
            // Second press - actually delete the network
            context.read(agentNetworksStateNotifierProvider.notifier).deleteNetwork(selectedIndex);
            setState(() {
              pendingDeleteIndex = null;
              if (selectedIndex >= component.networks.length - 1) {
                selectedIndex = (component.networks.length - 2).clamp(0, component.networks.length - 1);
              }
            });
          } else {
            // First press - set pending delete
            setState(() {
              pendingDeleteIndex = selectedIndex;
            });
          }
          return true;
        } else if (event.logicalKey == LogicalKey.enter) {
          final network = component.networks[selectedIndex];
          // Await resume to complete before navigating to prevent flash of empty state
          context.read(agentNetworkManagerProvider.notifier).resume(network).then((_) {
            NetworkExecutionPage.push(context, network.id);
          });
          return true;
        }
        return false;
      },
      child: ListView(
        lazy: true,
        controller: scrollController,
        children: [
          for (int i = 0; i < component.networks.length; i++) ...[
            NetworkSummaryComponent(
              network: component.networks[i],
              selected: selectedIndex == i,
              showDeleteConfirmation: pendingDeleteIndex == i,
            ),
            if (i < component.networks.length - 1) SizedBox(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Memory badge showing count of stored memories
class _MemoryBadge extends StatelessComponent {
  const _MemoryBadge({required this.count});

  final int count;

  @override
  Component build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: Colors.grey),
          child: Text('Memory', style: TextStyle(color: Colors.white)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: count > 0 ? Colors.green : Colors.black),
          child: Text(
            count.toString(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Settings badge
class _SettingsBadge extends StatelessComponent {
  const _SettingsBadge();

  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: Colors.grey),
      child: Text('Settings', style: TextStyle(color: Colors.white)),
    );
  }
}
