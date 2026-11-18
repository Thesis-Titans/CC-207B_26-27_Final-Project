import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlesteps/models/child.dart';
import 'package:littlesteps/screens/ai/ai_suggestions_screen.dart';
import 'package:littlesteps/services/api_client.dart';

void main() {
  final testChild = Child(
    id: 'child-123',
    nickname: 'Maya',
    ageBand: '12-23m',
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
  );

  final sampleAiSuccessResponse = {
    'suggestions': [
      {
        'activityId': 'act-cups-tower',
        'title': 'Build a Cup Tower',
        'whyPicked':
            'Matches your available cups and encourages fine motor stacking.',
        'activity': {
          'id': 'act-cups-tower',
          'title': 'Build a Cup Tower',
          'type': 'activity',
          'language': 'en',
          'domain': 'motor',
          'ageBand': '12-23m',
          'durationMinutes': 15,
          'durationEstimate': '15 mins',
          'setting': 'indoor',
          'materials': ['paper cups'],
          'instructions': [
            'Place cups on the floor.',
            'Show how to stack one over the other.',
            'Celebrate when knocked down gently.',
          ],
          'limitations': 'Supervise closely.',
          'status': 'reviewed_approved',
          'provenanceSource': 'LittleSteps Catalog',
        },
      },
    ],
    'source': 'ai',
    'tier': 1,
    'provenance': {
      'badge': 'Suggested by AI',
      'label': null,
      'disclaimer':
          'Observational play suggestion only. Not developmental assessment.',
      'model': 'gemini-flash-lite-latest',
      'reviewed': true,
    },
  };

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders input form with privacy notice and choice options', (
    tester,
  ) async {
    configureViewport(tester);

    final client = MockClient((request) async {
      return http.Response(jsonEncode({}), 200);
    });
    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idea Helper'), findsOneWidget);
    expect(find.text('How much time do you have?'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Where will you play?'), findsOneWidget);
    expect(find.text('Indoor or outdoor'), findsOneWidget);
    expect(find.text('What do you have at home?'), findsOneWidget);
    expect(
      find.text('Materials only, no names. Comma-separated.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'We send only: time, setting, materials, and age band. Child names and notes are never sent.',
      ),
      findsOneWidget,
    );
    expect(find.text('Find play ideas'), findsOneWidget);
  });

  testWidgets(
    'submits request without child name and displays AI suggestion with badge and disclaimer',
    (tester) async {
      configureViewport(tester);

      http.Request? capturedRequest;

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          capturedRequest = request;
          return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'paper cups, spoon');
      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['materials'], ['paper cups', 'spoon']);
      expect(body['timeMinutes'], 15);
      expect(body['setting'], 'either');
      expect(body['ageBand'], '12-23m');
      expect(body.containsKey('nickname'), isFalse);
      expect(body.containsKey('childName'), isFalse);
      expect(capturedRequest!.body.contains('Maya'), isFalse);

      expect(find.text('Suggested by AI'), findsOneWidget);
      expect(
        find.text(
          'AI Suggestion — Always adapt to your child and ensure adult supervision.',
        ),
        findsOneWidget,
      );
      expect(find.text('Build a Cup Tower'), findsOneWidget);
      expect(find.text('Item ID: act-cups-tower'), findsOneWidget);
      expect(
        find.text(
          'Why this fits: Matches your available cups and encourages fine motor stacking.',
        ),
        findsOneWidget,
      );
      expect(find.text('Materials needed:'), findsOneWidget);
      expect(find.text('paper cups'), findsOneWidget);
      expect(find.text('Steps to play:'), findsOneWidget);
      expect(find.text("Add to today's plan"), findsOneWidget);
      expect(find.text('Generate another'), findsOneWidget);
      expect(find.text('Change answers'), findsOneWidget);

      await tester.ensureVisible(find.text('Change answers'));
      await tester.tap(find.text('Change answers'));
      await tester.pumpAndSettle();
      expect(find.text('Idea Helper'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );

  testWidgets(
    'displays rate-limited state on HTTP 429 with catalog link and safe fallback',
    (tester) async {
      configureViewport(tester);

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'RATE_LIMITED',
                'message': 'Rate limit exceeded.',
              },
            }),
            429,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Taking a short break'), findsOneWidget);
      expect(
        find.text(
          "Let's take a short break. You've asked for many ideas in a row. Please wait a minute, then try again.",
        ),
        findsOneWidget,
      );
      expect(find.text('Browse activity catalog'), findsOneWidget);
      expect(find.text('Catalog picks · not AI'), findsOneWidget);
      expect(find.text('Suggested by AI'), findsNothing);
    },
  );

  testWidgets(
    'handles server error gracefully with catalog fallback labeled without AI badge',
    (tester) async {
      configureViewport(tester);

      final client = MockClient((request) async {
        if (request.url.path.contains('/api/v1/ai/recommendations')) {
          return http.Response('Server Error', 500);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

      await tester.pumpWidget(
        MaterialApp(
          home: AiSuggestionsScreen(
            apiClient: apiClient,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Find play ideas'));
      await tester.tap(find.text('Find play ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Catalog picks · not AI'), findsWidgets);
      expect(
        find.text(
          "The idea helper isn't working right now. Here are a few favorites for this age from our activity list.",
        ),
        findsOneWidget,
      );
      expect(find.text('Suggested by AI'), findsNothing);
      expect(find.text('Water and Cups Exploration'), findsOneWidget);
      expect(find.text("Add to today's plan"), findsWidgets);
    },
  );

  testWidgets('adds suggestion to today plan and shows SnackBar', (
    tester,
  ) async {
    configureViewport(tester);

    String? addedActivityId;

    final client = MockClient((request) async {
      if (request.url.path.contains('/api/v1/ai/recommendations')) {
        return http.Response(jsonEncode(sampleAiSuccessResponse), 200);
      }
      if (request.url.path.contains('/plans') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        addedActivityId = body['activityId'] as String?;
        return http.Response(
          jsonEncode({
            'id': 'plan-1',
            'childId': testChild.id,
            'activityId': addedActivityId,
            'scheduledDate': body['scheduledDate'],
            'status': 'planned',
            'createdAt': '2026-11-18T00:00:00Z',
            'updatedAt': '2026-11-18T00:00:00Z',
          }),
          201,
        );
      }
      return http.Response(jsonEncode({}), 200);
    });

    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Add to today's plan").first);
    await tester.tap(find.text("Add to today's plan").first);
    await tester.pumpAndSettle();

    expect(addedActivityId, 'act-cups-tower');
    expect(
      find.text('Added "Build a Cup Tower" to today\'s plan'),
      findsOneWidget,
    );
  });

  testWidgets('displays loading state during pending request', (tester) async {
    configureViewport(tester);

    final completer = Completer<http.Response>();
    final client = MockClient((request) async => completer.future);
    final apiClient = ApiClient(baseUrl: 'http://test', httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: AiSuggestionsScreen(
          apiClient: apiClient,
          initialChild: testChild,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find play ideas'));
    await tester.tap(find.text('Find play ideas'));
    await tester.pump();

    expect(
      find.text('Finding ideas… This usually takes a few seconds.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(http.Response(jsonEncode(sampleAiSuccessResponse), 200));
    await tester.pumpAndSettle();
    expect(find.text('Suggested by AI'), findsOneWidget);
  });
}
