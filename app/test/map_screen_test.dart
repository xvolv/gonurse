import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/features/map/map_screen.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

void main() {
  final course = Course.fromJson(
    jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  late Box uiBox;

  // In memory: a file-backed box never finishes writing inside widget tests.
  setUp(() async => uiBox = await Hive.openBox('ui', bytes: Uint8List(0)));
  tearDown(() => uiBox.close());

  Future<void> pumpMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider.overrideWith((ref, id) => course),
          uiBoxProvider.overrideWithValue(uiBox),
        ],
        child: const MaterialApp(
          home: MapScreen(courseId: 'pharmacology', title: 'Pharmacology'),
        ),
      ),
    );
  }

  testWidgets('shows the 8 units, all closed', (tester) async {
    await pumpMap(tester);
    for (final unit in course.units) {
      expect(find.text(unit.title), findsOneWidget);
    }
    expect(course.units, hasLength(8));
    expect(find.text('Heart failure'), findsNothing);
    expect(
      find.text('10'),
      findsOneWidget,
      reason: 'Renal & Cardiovascular count',
    );
  });

  testWidgets('opening a unit and a topic shows its notes, and is remembered', (
    tester,
  ) async {
    await pumpMap(tester);
    await tester.tap(find.text('Renal & Cardiovascular'));
    await tester.pump();
    await tester.tap(find.text('Heart failure'));
    await tester.pump();
    expect(
      find.text('Is this digoxin toxicity? What do you do?'),
      findsOneWidget,
    );
    expect(
      uiBox.get('map_open_pharmacology'),
      unorderedEquals(['u:cvs', 't:cvs/Heart failure']),
    );

    // Closing the unit hides its topics.
    await tester.tap(find.text('Renal & Cardiovascular'));
    await tester.pump();
    expect(
      find.text('Is this digoxin toxicity? What do you do?'),
      findsNothing,
    );
  });

  testWidgets('search shows matching notes with breadcrumb', (tester) async {
    await pumpMap(tester);
    await tester.enterText(find.byType(TextField), 'DIGO');
    await tester.pump();
    expect(
      find.text('Is this digoxin toxicity? What do you do?'),
      findsOneWidget,
    );
    expect(find.text('Renal & Cardiovascular › Heart failure'), findsOneWidget);
    expect(
      find.text('General Pharmacology'),
      findsNothing,
      reason: 'tree hidden',
    );

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text('No notes match "zzzz"'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('General Pharmacology'), findsOneWidget);
  });

  testWidgets('tapping a note opens it by ID', (tester) async {
    await pumpMap(tester);
    await tester.enterText(find.byType(TextField), 'digo');
    await tester.pump();
    await tester.tap(find.text('Is this digoxin toxicity? What do you do?'));
    await tester.pumpAndSettle();
    expect(
      find.text('THE SITUATION'),
      findsOneWidget,
      reason: 'reader is open',
    );
    expect(
      find.text('Pharmacology › Renal & Cardiovascular › Heart failure'),
      findsOneWidget,
    );
  });
}
