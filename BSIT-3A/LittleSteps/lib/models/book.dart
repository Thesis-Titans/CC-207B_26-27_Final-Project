/// A picture book entry from the reading catalog.
class Book {
  /// Creates a [Book].
  const Book({
    required this.id,
    required this.title,
    required this.authors,
    this.coverUrl,
    required this.subjects,
  });

  /// Unique catalog identifier for the book.
  final String id;

  /// Display title of the book.
  final String title;

  /// Author names credited on the book.
  final List<String> authors;

  /// Optional URL for the book cover image.
  final String? coverUrl;

  /// Thematic subject tags associated with the book.
  final List<String> subjects;

  /// Creates a [Book] from a decoded JSON object.
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

  /// Serializes this [Book] to a JSON map.
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
