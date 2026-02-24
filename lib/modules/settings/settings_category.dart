/// Settings category enum for navigation.
enum SettingsCategory {
  general('General'),
  team('Team'),
  appearance('Appearance'),
  daemon('Daemon'),
  debug('Debug'),
  mcpServers('MCP Servers'),
  about('About');

  const SettingsCategory(this.label);
  final String label;
}
