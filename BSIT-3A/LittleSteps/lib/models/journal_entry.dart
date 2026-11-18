/// A private caregiver journal entry.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.childId,
    required this.entryDate,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String entryDate;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      childId: json['childId'] as String,
      entryDate: json['entryDate'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'entryDate': entryDate,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
