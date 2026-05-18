/// A filesystem entry returned by the directory listing API.
class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final String? relativePath;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.relativePath,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
    name: json['name'] as String,
    path: json['path'] as String,
    isDirectory: json['is-directory'] as bool,
    relativePath: json['relative-path'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'is-directory': isDirectory,
    if (relativePath != null) 'relative-path': relativePath,
  };
}
