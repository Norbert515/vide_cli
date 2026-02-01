/// Settings category enum for navigation.
enum SettingsCategory {
  general('General', 'Basic settings'),
  appearance('Appearance', 'Theme and colors'),
  mcpServers('MCP Servers', 'Manage MCP server connections'),
  about('About', 'Version and information');

  const SettingsCategory(this.label, this.description);
  final String label;
  final String description;
}
