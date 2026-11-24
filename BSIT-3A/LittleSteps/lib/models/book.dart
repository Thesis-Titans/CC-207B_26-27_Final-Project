/// A book returned by the catalog.
class BookItem {
  /// Creates a [BookItem].
  const BookItem({
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

  /// Creates a [BookItem] from a decoded JSON object.
  factory BookItem.fromJson(Map<String, dynamic> json) {
    return BookItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Book',
      authors: _stringList(json['authors']),
      coverUrl: json['coverUrl'] as String?,
      subjects: _stringList(json['subjects']),
    );
  }

  /// Serializes this [BookItem] to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    if (coverUrl != null) 'coverUrl': coverUrl,
    'subjects': subjects,
  };
}

/// Catalog book kept for compatibility with existing service API.
class Book extends BookItem {
  /// Creates a [Book].
  const Book({
    required super.id,
    required super.title,
    required super.authors,
    super.coverUrl,
    required super.subjects,
  });

  /// Creates a [Book] from a decoded JSON object.
  factory Book.fromJson(Map<String, dynamic> json) {
    final item = BookItem.fromJson(json);
    return Book(
      id: item.id,
      title: item.title,
      authors: item.authors,
      coverUrl: item.coverUrl,
      subjects: item.subjects,
    );
  }
}

/// A book saved to a child's bookshelf.
class SavedBook extends BookItem {
  /// Creates a [SavedBook].
  const SavedBook({
    required super.id,
    required this.childId,
    required super.title,
    required super.authors,
    super.coverUrl,
    required super.subjects,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Child profile identifier owning this saved book record.
  final String childId;

  /// Timestamp when the book was saved to the shelf.
  final DateTime createdAt;

  /// Timestamp when the saved book record was last updated.
  final DateTime updatedAt;

  /// Creates a [SavedBook] from a decoded JSON object.
  factory SavedBook.fromJson(Map<String, dynamic> json) {
    final item = BookItem.fromJson(json);
    return SavedBook(
      id: item.id,
      childId: json['childId'] as String,
      title: item.title,
      authors: item.authors,
      coverUrl: item.coverUrl,
      subjects: item.subjects,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this [SavedBook] back to a base [BookItem].
  BookItem toBook() => BookItem(
    id: id,
    title: title,
    authors: authors,
    coverUrl: coverUrl,
    subjects: subjects,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'childId': childId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

List<String> _stringList(dynamic value) =>
    (value as List<dynamic>?)?.map((item) => item.toString()).toList() ??
    const [];
