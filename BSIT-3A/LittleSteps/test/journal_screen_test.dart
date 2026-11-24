import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/models/auth_user.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/models/journal_entry.dart';
import 'package:littlesteps/screens/journal/journal_screen.dart';
import 'package:littlesteps/services/api_client.dart';
import 'package:littlesteps/services/auth_service.dart';
import 'package:littlesteps/services/auth_session_state.dart';
import 'package:littlesteps/services/journal_service.dart';
import 'package:littlesteps/theme/app_theme.dart';
import 'package:littlesteps/widgets/auth_scope.dart';

void main() {
  final now = DateTime(2026, 11, 24, 10);
  final maya = Child(
    id: 'child-maya',
    nickname: 'Maya',
    ageBand: '12-23m',
    createdAt: now,
    updatedAt: now,
  );
  final tala = Child(
    id: 'child-tala',
    nickname: 'Tala',
    ageBand: '24-35m',
    createdAt: now,
    updatedAt: now,
  );

  JournalEntry entry({
    required String id,
    String childId = 'child-maya',
    String date = '2026-11-24',
    required String content,
  }) => JournalEntry(
    id: id,
    childId: childId,
    entryDate: date,
    content: content,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('renders actionable empty state and creates a private note', (
    tester,
  ) async {
    final service = _FakeJournalService(entriesByChild: {'child-maya': []});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(journalService: service, activeChild: maya),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notes for Maya yet'), findsOneWidget);
    expect(
      find.text(
        'Only you can see your notes. They are never shared or sent to AI.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Private by design'), findsNothing);
    expect(find.text('Add note'), findsOneWidget);

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('0 / 2,000'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('journal-note-input')),
      'Maya stacked four cups and clapped.',
    );
    await tester.pump();
    expect(find.text('35 / 2,000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('journal-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Maya stacked four cups and clapped.'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });

  testWidgets('enforces 2,000-character limit with validation message', (
    tester,
  ) async {
    final service = _FakeJournalService(entriesByChild: {'child-maya': []});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(journalService: service, activeChild: maya),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('journal-note-input')),
      'a' * 2005,
    );
    await tester.pump();
    expect(find.text('2005 / 2,000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('journal-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Notes can be up to 2,000 characters. Please make this one a little shorter.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('supports search, editing, and confirmed deletion', (
    tester,
  ) async {
    final service = _FakeJournalService(
      entriesByChild: {
        'child-maya': [
          entry(
            id: 'j1',
            date: '2026-11-22',
            content: 'Enjoyed Bahay Kubo song.',
          ),
          entry(id: 'j2', date: '2026-11-24', content: 'Stacked plastic cups.'),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(journalService: service, activeChild: maya),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stacked plastic cups.'), findsOneWidget);
    expect(find.text('Enjoyed Bahay Kubo song.'), findsOneWidget);

    // Search filters notes locally.
    await tester.enterText(
      find.byKey(const ValueKey('journal-search')),
      'Bahay',
    );
    await tester.pumpAndSettle();
    expect(find.text('Enjoyed Bahay Kubo song.'), findsOneWidget);
    expect(find.text('Stacked plastic cups.'), findsNothing);

    // Edit note.
    await tester.tap(find.byTooltip('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-note-input')),
      'Sang Bahay Kubo with clapping.',
    );
    await tester.tap(find.byKey(const ValueKey('journal-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Sang Bahay Kubo with clapping.'), findsOneWidget);

    // Delete requires confirmation.
    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this note?'), findsOneWidget);

    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    expect(find.text('Sang Bahay Kubo with clapping.'), findsNothing);
  });

  testWidgets('shows neutral access-denied view on HTTP 403 or 404', (
    tester,
  ) async {
    final service = _FakeJournalService(
      entriesByChild: const {},
      getError: ApiException(
        statusCode: 404,
        code: 'RESOURCE_NOT_FOUND',
        message: 'Not found',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(journalService: service, activeChild: maya),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        "We can't open this note. It may have been deleted. Your own notes are safe.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps unsaved draft in open sheet and AuthScope when offline', (
    tester,
  ) async {
    final session = AuthSessionState(authService: _FakeAuthService());
    await session.signIn(email: 'ana@example.com', password: 'Password123!');
    session.setActiveChild(maya);

    final service = _FakeJournalService(
      entriesByChild: {'child-maya': []},
      createError: NoConnectionApiException(),
    );

    await tester.pumpWidget(
      AuthScope(
        sessionState: session,
        apiClient: ApiClient(baseUrl: 'http://test'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: JournalScreen(journalService: service)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('journal-note-input')),
      'Offline draft preserved safely.',
    );
    await tester.tap(find.byKey(const ValueKey('journal-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(session.unsavedDraft, 'Offline draft preserved safely.');
  });

  testWidgets(
    'clears notes immediately and drops stale responses on child switch',
    (tester) async {
      final session = AuthSessionState(authService: _FakeAuthService());
      await session.signIn(email: 'ana@example.com', password: 'Password123!');
      session.setActiveChild(maya);

      final mayaCompleter = Completer<List<JournalEntry>>();
      final service = _DelayedJournalService(
        mayaCompleter: mayaCompleter,
        talaEntries: const [],
      );

      await tester.pumpWidget(
        AuthScope(
          sessionState: session,
          apiClient: ApiClient(baseUrl: 'http://test'),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: JournalScreen(journalService: service)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Switch to Tala before Maya's slow request completes.
      session.setActiveChild(tala);
      await tester.pumpAndSettle();

      // Now Maya's stale response arrives; it must NOT render under Tala.
      mayaCompleter.complete([
        entry(id: 'j-secret', content: 'Maya private secret note'),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.text('Everyday moments and notes about Tala.'),
        findsOneWidget,
      );
      expect(find.text('Maya private secret note'), findsNothing);
      expect(find.text('No notes for Tala yet'), findsOneWidget);
    },
  );
}

class _FakeJournalService extends JournalService {
  _FakeJournalService({
    required this.entriesByChild,
    this.getError,
    this.createError,
  }) : super(apiClient: ApiClient(baseUrl: 'http://test'));

  final Map<String, List<JournalEntry>> entriesByChild;
  final Object? getError;
  final Object? createError;
  int _nextId = 100;

  @override
  Future<List<JournalEntry>> getJournalEntries(String childId) async {
    if (getError != null) throw getError!;
    return List.of(entriesByChild[childId] ?? const []);
  }

  @override
  Future<JournalEntry> createJournalEntry({
    required String childId,
    required String entryDate,
    required String content,
  }) async {
    if (createError != null) throw createError!;
    final now = DateTime(2026, 11, 24, 12);
    final created = JournalEntry(
      id: 'j-${_nextId++}',
      childId: childId,
      entryDate: entryDate,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    entriesByChild.putIfAbsent(childId, () => []).add(created);
    return created;
  }

  @override
  Future<JournalEntry> updateJournalEntry({
    required String childId,
    required String entryId,
    required String content,
  }) async {
    final list = entriesByChild[childId] ?? [];
    final idx = list.indexWhere((e) => e.id == entryId);
    final old = list[idx];
    final updated = JournalEntry(
      id: old.id,
      childId: old.childId,
      entryDate: old.entryDate,
      content: content,
      createdAt: old.createdAt,
      updatedAt: DateTime(2026, 11, 24, 13),
    );
    list[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteJournalEntry({
    required String childId,
    required String entryId,
  }) async {
    entriesByChild[childId]?.removeWhere((e) => e.id == entryId);
  }
}

class _DelayedJournalService extends JournalService {
  _DelayedJournalService({
    required this.mayaCompleter,
    required this.talaEntries,
  }) : super(apiClient: ApiClient(baseUrl: 'http://test'));

  final Completer<List<JournalEntry>> mayaCompleter;
  final List<JournalEntry> talaEntries;

  @override
  Future<List<JournalEntry>> getJournalEntries(String childId) {
    if (childId == 'child-maya') return mayaCompleter.future;
    return Future.value(talaEntries);
  }
}

class _FakeAuthService implements AuthService {
  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AuthUser(
    id: 'u1',
    email: email,
    idToken: 'tok-123',
    refreshToken: 'ref-123',
    expiresAt: DateTime(2030),
  );

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) => signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<AuthUser> refreshToken(String refreshToken) =>
      signInWithEmailAndPassword(email: 'ana@example.com', password: 'x');

  @override
  Future<void> signOut() async {}
}
