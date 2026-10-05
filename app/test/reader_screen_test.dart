import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

void main() {
  final realJson =
      jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
          as Map<String, dynamic>;
  final course = Course.fromJson(realJson);
  late Box uiBox;

  // In memory: a file-backed box never finishes writing inside widget tests.
  setUp(() async => uiBox = await Hive.openBox('ui', bytes: Uint8List(0)));
  tearDown(() => uiBox.close());

  Future<void> pumpReader(
    WidgetTester tester,
    String noteId, {
    Course? withCourse,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseProvider.overrideWith((ref, id) => withCourse ?? course),
          uiBoxProvider.overrideWithValue(uiBox),
        ],
        child: MaterialApp(
          home: ReaderScreen(courseId: 'pharmacology', noteId: noteId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? savedNote() => (uiBox.get('last_note') as Map?)?['note'] as String?;

  testWidgets(
    'shows a note with breadcrumb, position, numbered lines and refs',
    (tester) async {
      await pumpReader(tester, 'digoxin');
      final topic = course.topicByNoteId['digoxin']!;
      final pos = topic.notes.indexWhere((n) => n.id == 'digoxin') + 1;

      expect(find.text('Digoxin'), findsOneWidget);
      expect(
        find.text('Pharmacology › Renal & Cardiovascular › Heart failure'),
        findsOneWidget,
      );
      expect(find.text('$pos / ${topic.notes.length}'), findsOneWidget);
      expect(find.text('THE BIG IDEA'), findsOneWidget);
      expect(find.text('EXAM TRAP'), findsOneWidget);
      expect(find.text('CVS p.96-97, RCVS p.116'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('RELATED'), findsOneWidget);
      expect(savedNote(), 'digoxin');
    },
  );

  testWidgets('swiping past the end of a topic continues into the next topic', (
    tester,
  ) async {
    final hf = course.units
        .expand((u) => u.topics)
        .firstWhere((t) => t.title == 'Heart failure');
    final next = course.allNotes[course.allNotes.indexOf(hf.notes.last) + 1];
    await pumpReader(tester, hf.notes.last.id);
    expect(
      find.text('${hf.notes.length} / ${hf.notes.length}'),
      findsOneWidget,
    );

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text(next.title), findsWidgets);
    expect(
      find.text('1 / ${course.topicByNoteId[next.id]!.notes.length}'),
      findsOneWidget,
    );
    expect(savedNote(), next.id);

    await tester.fling(find.byType(PageView), const Offset(600, 0), 2000);
    await tester.pumpAndSettle();
    expect(savedNote(), hf.notes.last.id);
  });

  testWidgets('related chip jumps to the linked note', (tester) async {
    await pumpReader(tester, 'digoxin');
    final linked = course.notesById[course.notesById['digoxin']!.links.first]!;
    await tester.tap(find.widgetWithText(ActionChip, linked.title));
    await tester.pumpAndSettle();
    expect(
      find.text([course.course, ...linked.path].join(' › ')),
      findsOneWidget,
    );
    expect(savedNote(), linked.id);
  });

  testWidgets('a ref with several sources offers a menu', (tester) async {
    await pumpReader(tester, 'digoxin');
    await tester.tap(find.text('CVS p.96-97, RCVS p.116'));
    await tester.pumpAndSettle();
    expect(find.text('CVS p.96-97'), findsOneWidget);
    expect(find.text('RCVS p.116'), findsOneWidget);
    expect(find.text('CVS pharmacology (1).pdf'), findsOneWidget);
  });

  testWidgets('flags show in a Check box', (tester) async {
    await pumpReader(tester, 'bp-reg');
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Her files disagree'), findsOneWidget);
  });

  testWidgets('bedside format: new sections, practice tag, unknown type', (
    tester,
  ) async {
    final bedside = Course.fromJson({
      ...realJson,
      'units': [
        {
          'id': 'cvs',
          'title': 'Renal & Cardiovascular',
          'topics': [
            {
              'title': 'Heart failure',
              'notes': [
                {
                  'id': 'digoxin',
                  'title': 'Digoxin',
                  'path': ['Renal & Cardiovascular', 'Heart failure'],
                  'sections': [
                    {
                      'type': 'scene',
                      'title': "The patient you'll meet",
                      'lines': [
                        {
                          'n': 1,
                          'text': 'An older patient with heart failure.',
                          'ref': 'CVS p.98',
                        },
                      ],
                    },
                    {
                      'type': 'actions',
                      'title': 'What the nurse does',
                      'lines': [
                        {
                          'n': 2,
                          'text': 'Check apical pulse for a full minute.',
                          'ref': '',
                          'basis': 'practice',
                        },
                      ],
                    },
                    {
                      'type': 'traps',
                      'title': '',
                      'lines': [
                        {
                          'n': 3,
                          'text': 'Never give more digoxin.',
                          'ref': 'RCVS p.117',
                        },
                      ],
                    },
                    {
                      'type': 'mnemonic',
                      'title': 'Memory trick',
                      'lines': [
                        {
                          'n': 4,
                          'text': 'Yellow vision = digoxin.',
                          'ref': 'CVS p.100',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
    await pumpReader(tester, 'digoxin', withCourse: bedside);

    expect(find.text("THE PATIENT YOU'LL MEET"), findsOneWidget);
    expect(find.text('WHAT THE NURSE DOES'), findsOneWidget);
    expect(
      find.text('HOW THE EXAM TRICKS YOU'),
      findsOneWidget,
      reason: 'default title',
    );
    expect(
      find.text('MEMORY TRICK'),
      findsOneWidget,
      reason: 'unknown type, title from JSON',
    );
    expect(find.text('Standard practice – confirm'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    final scene = tester.widget<Text>(
      find.text('An older patient with heart failure.'),
    );
    expect(scene.style!.fontStyle, FontStyle.italic);
    final context = tester.element(find.text('HOW THE EXAM TRICKS YOU'));
    expect(
      tester.widget<Text>(find.text('HOW THE EXAM TRICKS YOU')).style!.color,
      Theme.of(context).colorScheme.error,
    );
  });
}
