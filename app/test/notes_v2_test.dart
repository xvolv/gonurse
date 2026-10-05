import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/features/reader/section_style.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

/// Every note of the real (decision-format) Pharmacology file renders.
void main() {
  final course = Course.fromJson(
    jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final optionPattern = RegExp(r'^[a-d][.)]\s');

  test('every practice question: a stem, then a–d with exactly one ✓', () {
    for (final note in course.allNotes) {
      for (final s in note.sections.where((s) => s.type == 'worked')) {
        final texts = [for (final l in s.lines) l.text];
        expect(optionPattern.hasMatch(texts.first), isFalse, reason: note.id);
        final options = texts.skip(1).toList();
        expect(
          [for (final o in options) o[0]],
          ['a', 'b', 'c', 'd'],
          reason: note.id,
        );
        expect(
          options.where((o) => o.contains('✓')),
          hasLength(1),
          reason: note.id,
        );
        expect(
          options.where((o) => o.contains('✗')),
          hasLength(3),
          reason: note.id,
        );
      }
    }
  });

  group('reader', () {
    late Box uiBox;
    setUp(() async => uiBox = await Hive.openBox('ui', bytes: Uint8List(0)));
    tearDown(() => uiBox.close());

    for (final note in course.allNotes) {
      testWidgets('${note.id}: sections, practice boxes, no refs', (
        tester,
      ) async {
        // Tall enough that the whole note is built.
        tester.view.physicalSize = const Size(800, 9000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              courseProvider.overrideWith((ref, id) => course),
              uiBoxProvider.overrideWithValue(uiBox),
            ],
            child: MaterialApp(
              home: ReaderScreen(courseId: 'pharmacology', noteId: note.id),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final section in note.sections) {
          expect(
            find.text(sectionTitle(section).toUpperCase()),
            findsWidgets,
            reason: section.type,
          );
        }
        for (final line in note.lines) {
          expect(find.text(line.text), findsOneWidget);
        }

        // Each practice question sits in its own tinted box.
        final worked = note.sections.where((s) => s.type == 'worked').toList();
        final boxes = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('worked-box-'),
        );
        expect(boxes, findsNWidgets(worked.length));
        for (final line in worked.expand((s) => s.lines)) {
          expect(
            find.descendant(of: boxes, matching: find.text(line.text)),
            findsOneWidget,
          );
        }

        // Only text, titles and numbers: no refs or practice tags.
        for (final line in note.lines.where((l) => l.ref.isNotEmpty)) {
          expect(find.text(line.ref), findsNothing);
        }
        expect(
          find.textContaining(
            RegExp(r'\b(p\.|slide) ?\d|Standard practice|^Check$'),
          ),
          findsNothing,
        );
      });
    }
  });
}
