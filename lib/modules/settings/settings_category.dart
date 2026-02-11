/// Settings category enum for navigation.
enum SettingsCategory {
  general('General'),
  appearance('Appearance'),
  mcpServers('MCP Servers'),
  about('About');

  const SettingsCategory(this.label);
  final String label;
}
