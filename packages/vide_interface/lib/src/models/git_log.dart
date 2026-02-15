/// A git commit entry from the log API.
class GitCommitInfo {
  final String hash;
  final String author;
  final String message;
  final DateTime date;

  const GitCommitInfo({
    required this.hash,
    required this.author,
    required this.message,
    required this.date,
  });

  factory GitCommitInfo.fromJson(Map<String, dynamic> json) => GitCommitInfo(
        hash: json['hash'] as String,
        author: json['author'] as String,
        message: json['message'] as String,
        date: DateTime.parse(json['date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'author': author,
        'message': message,
        'date': date.toIso8601String(),
      };
}
