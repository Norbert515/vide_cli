import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/services/vide_settings.dart';

/// Page to view and modify Vide settings
class VideSettingsPage extends StatefulComponent {
  const VideSettingsPage({super.key});

  static Future push(BuildContext context) async {
    return Navigator.of(context).push(
      PageRoute(builder: (context) => VideSettingsPage(), settings: RouteSettings()),
    );
  }

  @override
  State<VideSettingsPage> createState() => _VideSettingsPageState();
}

class _VideSettingsPageState extends State<VideSettingsPage> {
  late VideSettings _settings;
  int _selectedIndex = 0;

  // Define settings as a list for easy navigation
  List<_SettingItem> get _settingItems => [
    _SettingItem(
      key: 'codeSommelier',
      label: 'Code Sommelier',
      description: 'Wine-tasting style commentary on pasted code',
      value: _settings.codeSommelierEnabled,
      onToggle: () => _toggleSetting('codeSommelier'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _settings = VideSettingsManager.instance.settings;
  }

  Future<void> _toggleSetting(String key) async {
    switch (key) {
      case 'codeSommelier':
        final newValue = !_settings.codeSommelierEnabled;
        await VideSettingsManager.instance.setCodeSommelierEnabled(newValue);
        setState(() {
          _settings = VideSettingsManager.instance.settings;
        });
        break;
    }
  }

  @override
  Component build(BuildContext context) {
    final items = _settingItems;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        // Up/Down to navigate
        if (event.logicalKey == LogicalKey.arrowUp && _selectedIndex > 0) {
          setState(() => _selectedIndex--);
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowDown && _selectedIndex < items.length - 1) {
          setState(() => _selectedIndex++);
          return true;
        }

        // Enter/Space to toggle
        if (event.logicalKey == LogicalKey.enter || event.logicalKey == LogicalKey.space) {
          items[_selectedIndex].onToggle();
          return true;
        }

        // Escape/Q to go back
        if (event.logicalKey == LogicalKey.escape || event.logicalKey == LogicalKey.keyQ) {
          Navigator.of(context).pop();
          return true;
        }

        return false;
      },
      child: Container(
        padding: EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              'Vide Settings',
              style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
            SizedBox(height: 1),

            // Help text
            Text(
              '↑↓ Navigate • Enter/Space Toggle • Q/Esc Back',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 2),

            // Settings list
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _SettingRow(
                      item: items[i],
                      isSelected: i == _selectedIndex,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingItem {
  final String key;
  final String label;
  final String description;
  final bool value;
  final VoidCallback onToggle;

  _SettingItem({
    required this.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onToggle,
  });
}

class _SettingRow extends StatelessComponent {
  final _SettingItem item;
  final bool isSelected;

  const _SettingRow({required this.item, required this.isSelected});

  @override
  Component build(BuildContext context) {
    final checkbox = item.value ? '[✓]' : '[ ]';
    final bgColor = isSelected ? Colors.blue : null;
    final textColor = isSelected ? Colors.white : Colors.white;

    return Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            checkbox,
            style: TextStyle(
              color: item.value ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                Text(item.description, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
