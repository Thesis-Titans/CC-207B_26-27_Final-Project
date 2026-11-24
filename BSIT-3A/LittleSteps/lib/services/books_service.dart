import '../models/book.dart';
import '../data/fallback_books.dart';
import 'api_client.dart';

/// Loads catalog books and manages a child's saved books.
class BooksService {
  BooksService({required this.apiClient});

  static const List<String> _subjects = [
    'picture_books',
    'animals',
    'bedtime',
    'colors',
  ];

  final ApiClient apiClient;

  Future<List<BookItem>> fetchBooks({
    String? subject = 'picture_books',
    int limit = 12,
  }) async {
    if (subject == null) {
      final results = await Future.wait(
        _subjects.map((item) => _fetchSubjectBooks(item, limit)),
      );
      final booksById = <String, BookItem>{};
      for (final books in results) {
        for (final book in books) {
          booksById.putIfAbsent(book.id, () => book);
        }
      }
      return booksById.values.toList();
    }

    return _fetchSubjectBooks(subject, limit);
  }

  Future<List<BookItem>> _fetchSubjectBooks(String subject, int limit) async {
    final queryParams = {'limit': limit.toString()};
    queryParams['subject'] = subject;

    final data = await apiClient.get(
      '/api/v1/catalog/books',
      queryParams: queryParams,
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => BookItem.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookItem>> searchBooks(String query, {int limit = 12}) async {
    final queryParams = {'q': query, 'limit': limit.toString()};

    final data = await apiClient.get(
      '/api/v1/catalog/books/search',
      queryParams: queryParams,
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => BookItem.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<List<SavedBook>> fetchSavedBooks(String childId) async {
    final data = await apiClient.get(
      '/api/v1/children/$childId/books',
    ) as Map<String, dynamic>;

    final booksRaw = data['books'] as List<dynamic>? ?? [];
    return booksRaw
        .map((b) => SavedBook.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<SavedBook> saveBookToShelf(String childId, BookItem book) async {
    final body = {
      'id': book.id,
      'title': book.title,
      'authors': book.authors,
      if (book.coverUrl != null) 'coverUrl': book.coverUrl,
      'subjects': book.subjects,
    };

    final data = await apiClient.post(
      '/api/v1/children/$childId/books',
      body: body,
    ) as Map<String, dynamic>;

    return SavedBook.fromJson(data);
  }

  Future<void> removeBookFromShelf(String childId, String bookId) async {
    await apiClient.delete('/api/v1/children/$childId/books/$bookId');
  }

  static List<BookItem> filterFallbackBooks([
    String? subject = 'picture_books',
    String? query,
  ]) {
    final cleanQuery = query?.trim().toLowerCase();
    if (cleanQuery != null && cleanQuery.isNotEmpty) {
      final matches = fallbackBooks.where((book) {
        return book.title.toLowerCase().contains(cleanQuery) ||
            book.authors.any(
              (author) => author.toLowerCase().contains(cleanQuery),
            ) ||
            book.subjects.any((tag) => tag.toLowerCase().contains(cleanQuery));
      }).toList();
      return matches;
    }

    if (subject == null) return fallbackBooks;
    final cleanSubject = subject.replaceAll('_', ' ').toLowerCase();
    final matching = fallbackBooks.where((book) {
      return book.subjects.any((s) => s.toLowerCase().contains(cleanSubject));
    }).toList();

    return matching.isNotEmpty ? matching : fallbackBooks;
  }
}
