/// A filesystem entry returned by the directory listing API.
class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
        name: json['name'] as String,
        path: json['path'] as String,
        isDirectory: json['is-directory'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'is-directory': isDirectory,
      };
}
