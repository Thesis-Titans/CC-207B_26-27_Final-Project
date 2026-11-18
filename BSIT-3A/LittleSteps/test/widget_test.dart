import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlesteps/main.dart';

void main() {
  testWidgets('shell shows five tabs and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(const LittleStepsApp());

    final nav = find.byType(NavigationBar);
    for (final label in [
      'Today',
      'Explore',
      'Milestones',
      'Journal',
      'This week',
    ]) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Select Child'), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Explore')));
    await tester.pumpAndSettle();
    expect(
      find.text('The age-aware activity catalog appears here.'),
      findsOneWidget,
    );
  });
}
