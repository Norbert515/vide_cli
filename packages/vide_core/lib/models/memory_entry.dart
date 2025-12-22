/// Represents a single memory entry stored by the memory service.
class MemoryEntry {
  MemoryEntry({
    required this.key,
    required this.value,
    required this.createdAt,
    this.updatedAt,
  });

  final String key;
  final String value;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      key: json['key'] as String,
      value: json['value'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  MemoryEntry copyWith({
    String? key,
    String? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryEntry(
      key: key ?? this.key,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
