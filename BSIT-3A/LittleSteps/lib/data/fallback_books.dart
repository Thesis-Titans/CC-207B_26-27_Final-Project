import '../models/book.dart';

/// Books shown when the catalog service is unavailable.
const fallbackBooks = <BookItem>[
  BookItem(
    id: 'OL52987W',
    title: 'The Very Hungry Caterpillar',
    authors: ['Eric Carle'],
    coverUrl: 'https://covers.openlibrary.org/b/id/7835968-M.jpg',
    subjects: ['Caterpillars', 'Metamorphosis', 'Picture books'],
  ),
  BookItem(
    id: 'OL151798W',
    title: 'Goodnight Moon',
    authors: ['Margaret Wise Brown'],
    coverUrl: 'https://covers.openlibrary.org/b/id/35556-M.jpg',
    subjects: ['Bedtime', 'Stories in rhyme', 'Rabbits'],
  ),
  BookItem(
    id: 'OL59133W',
    title: 'Brown Bear, Brown Bear, What Do You See?',
    authors: ['Bill Martin Jr.'],
    coverUrl: 'https://covers.openlibrary.org/b/id/12624136-M.jpg',
    subjects: ['Colors', 'Animals', 'Repetitive text'],
  ),
];
