/// A picture book entry from the reading catalog.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.authors,
    this.coverUrl,
    required this.subjects,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final List<String> subjects;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Book',
      authors:
          (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      coverUrl: json['coverUrl'] as String?,
      subjects:
          (json['subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'subjects': subjects,
    };
  }
}
