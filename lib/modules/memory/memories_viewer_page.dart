import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

/// Page to view memories stored for the current project
class MemoriesViewerPage extends StatefulComponent {
  const MemoriesViewerPage({super.key});

  static Future push(BuildContext context) async {
    return Navigator.of(context).push(
      PageRoute(
        builder: (context) => MemoriesViewerPage(),
        settings: RouteSettings(),
      ),
    );
  }

  @override
  State<MemoriesViewerPage> createState() => _MemoriesViewerPageState();
}

class _MemoriesViewerPageState extends State<MemoriesViewerPage> {
  int selectedIndex = 0;
  final scrollController = ScrollController();

  List<MemoryEntry>? _memories;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    final memoryService = context.read(memoryServiceProvider);
    final workingDir = context.read(workingDirProvider);

    final memories = await memoryService.list(workingDir);

    // Sort by key
    memories.sort((a, b) => a.key.compareTo(b.key));

    setState(() {
      _memories = memories;
      _loading = false;
    });
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    if (_loading) {
      return Container(
        padding: EdgeInsets.all(2),
        child: Center(
          child: Text(
            'Loading memories...',
            style: TextStyle(color: theme.base.outline),
          ),
        ),
      );
    }

    final memories = _memories ?? [];

    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Text(
            'Project Memory',
            style: TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 1),
          // Stats
          _Badge(
            label: 'Keys',
            value: memories.length.toString(),
            labelBg: theme.base.outline,
            valueBg: theme.base.primary,
            valueColor: theme.base.onSurface,
          ),
          SizedBox(height: 1),
          // Help text
          Text(
            'Esc: back | ↑/↓: navigate',
            style: TextStyle(color: theme.base.outline),
          ),
          SizedBox(height: 2),
          // Content
          Expanded(
            child: memories.isEmpty
                ? Center(
                    child: Text(
                      'No memories stored yet',
                      style: TextStyle(color: theme.base.outline),
                    ),
                  )
                : _MemoryList(
                    memories: memories,
                    selectedIndex: selectedIndex,
                    scrollController: scrollController,
                    onIndexChanged: (index) {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                  ),
          ),
          SizedBox(height: 2),
        ],
      ),
    );
  }
}

/// List of memories with keyboard navigation
class _MemoryList extends StatelessComponent {
  const _MemoryList({
    required this.memories,
    required this.selectedIndex,
    required this.scrollController,
    required this.onIndexChanged,
  });

  final List<MemoryEntry> memories;
  final int selectedIndex;
  final ScrollController scrollController;
  final void Function(int) onIndexChanged;

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowDown ||
            event.logicalKey == LogicalKey.keyJ) {
          final newIndex = (selectedIndex + 1).clamp(0, memories.length - 1);
          onIndexChanged(newIndex);
          scrollController.ensureIndexVisible(index: newIndex);
          return true;
        } else if (event.logicalKey == LogicalKey.arrowUp ||
            event.logicalKey == LogicalKey.keyK) {
          final newIndex = (selectedIndex - 1).clamp(0, memories.length - 1);
          onIndexChanged(newIndex);
          scrollController.ensureIndexVisible(index: newIndex);
          return true;
        }
        return false;
      },
      child: ListView(
        lazy: true,
        controller: scrollController,
        children: [
          for (int i = 0; i < memories.length; i++) ...[
            _MemoryEntryComponent(
              memory: memories[i],
              selected: selectedIndex == i,
            ),
            if (i < memories.length - 1) SizedBox(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Individual memory entry display
class _MemoryEntryComponent extends StatelessComponent {
  const _MemoryEntryComponent({required this.memory, required this.selected});

  final MemoryEntry memory;
  final bool selected;

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    // Truncate value if too long
    final displayValue = memory.value.length > 100
        ? '${memory.value.substring(0, 100)}...'
        : memory.value;

    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: selected
            ? theme.base.surface
            : theme.base.surface.withOpacity(0),
        border: BoxBorder.all(
          color: selected
              ? theme.base.primary
              : theme.base.surface.withOpacity(0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key
          Text(
            memory.key,
            style: TextStyle(
              color: theme.base.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 1),
          // Value
          Text(displayValue, style: TextStyle(color: theme.base.onSurface)),
        ],
      ),
    );
  }
}

/// GitHub-style badge component
class _Badge extends StatelessComponent {
  const _Badge({
    required this.label,
    required this.value,
    required this.labelBg,
    required this.valueBg,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelBg;
  final Color valueBg;
  final Color valueColor;

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: labelBg),
          child: Text(label, style: TextStyle(color: theme.base.onSurface)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: valueBg),
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
