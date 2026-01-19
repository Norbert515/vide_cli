/// Settings category enum for navigation.
enum SettingsCategory {
  general('General', 'Basic settings'),
  appearance('Appearance', 'Theme and colors'),
  server('Server', 'Embedded HTTP/WebSocket server'),
  mcpServers('MCP Servers', 'Manage MCP server connections'),
  permissions('Permissions', 'Configure access permissions'),
  about('About', 'Version and information');

  const SettingsCategory(this.label, this.description);
  final String label;
  final String description;
}
