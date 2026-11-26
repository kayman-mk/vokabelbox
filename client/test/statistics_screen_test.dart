import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vokabelbox/api.dart';
import 'package:vokabelbox/screens/statistics_screen.dart';

void main() {
  testWidgets('shows box statistics and fetches them separately by direction', (tester) async {
    final requestedDirections = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requestedDirections.add(request.url.queryParameters['direction']!);
        return http.Response(
          jsonEncode({
            'method': 'fsrs',
            'direction': request.url.queryParameters['direction'],
            'progress': {
              'total': 4,
              'new_count': 2,
              'due_count': 1,
              'reviewed_count': 2,
              'repetitions': 5,
              'lapses': 1,
            },
            'reviews': {
              'total': 5,
              'again_count': 1,
              'hard_count': 1,
              'good_count': 2,
              'easy_count': 1,
              'first_review_at': '2026-11-20 10:00:00',
              'last_review_at': '2026-11-26 10:00:00',
            },
            'dailyActivity': [
              {'day': '2026-11-26', 'reviews': 5, 'againCount': 1},
            ],
          }),
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: StatisticsScreen(
        api: api,
        vocabularySet: const VocabularySet(id: 'box-1', name: 'German', wordCount: 4),
      ),
    ));
    await tester.pumpAndSettle();

    expect(requestedDirections, ['foreign_to_local']);
    expect(find.text('German'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('5'), findsWidgets);

    await tester.tap(find.text('Lokal → fremd'));
    await tester.pumpAndSettle();
    expect(requestedDirections, ['foreign_to_local', 'local_to_foreign']);
    expect(find.text('Muttersprache → Fremdsprache'), findsOneWidget);
  });

  testWidgets('opens the FSRS reference page from statistics', (tester) async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'progress': {
                'total': 0,
                'new_count': 0,
                'due_count': 0,
                'reviewed_count': 0,
                'repetitions': 0,
                'lapses': 0,
              },
              'reviews': {
                'total': 0,
                'again_count': 0,
                'hard_count': 0,
                'good_count': 0,
                'easy_count': 0,
                'first_review_at': null,
                'last_review_at': null,
              },
              'dailyActivity': [],
            }),
            headers: {'content-type': 'application/json'},
          )),
    );
    await tester.pumpWidget(MaterialApp(
      home: StatisticsScreen(
        api: api,
        vocabularySet: const VocabularySet(id: 'box-1', name: 'German', wordCount: 0),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('FSRS Referenz'));
    await tester.pumpAndSettle();

    expect(find.text('FSRS Referenz'), findsOneWidget);
    expect(find.text('Algorithmusversion: FSRS-4.5'), findsOneWidget);
    expect(find.textContaining('github.com/open-spaced-repetition/awesome-fsrs'), findsOneWidget);
  });
}
