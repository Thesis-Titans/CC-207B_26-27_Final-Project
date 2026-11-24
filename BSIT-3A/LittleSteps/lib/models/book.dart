/// A book returned by the catalog.
class BookItem {
  const BookItem({
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

  factory BookItem.fromJson(Map<String, dynamic> json) {
    return BookItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Book',
      authors: _stringList(json['authors']),
      coverUrl: json['coverUrl'] as String?,
      subjects: _stringList(json['subjects']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    if (coverUrl != null) 'coverUrl': coverUrl,
    'subjects': subjects,
  };
}

/// Catalog book kept for the existing service API.
class Book extends BookItem {
  const Book({
    required super.id,
    required super.title,
    required super.authors,
    super.coverUrl,
    required super.subjects,
  });

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

  final String childId;
  final DateTime createdAt;
  final DateTime updatedAt;

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
