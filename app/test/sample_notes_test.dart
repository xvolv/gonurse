import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/data/ref_parser.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/features/reader/section_style.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

/// The 5 sample notes in the decision format (not published yet).
void main() {
  final sample = Course.fromJson(
    jsonDecode(
          File(
            '../content/samples/pharmacology_notes_v2_SAMPLE.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  group('sample file', () {
    test('all 5 notes load, numbered 1..N', () {
      expect(sample.version, 2);
      expect(sample.noteCount, 5);
      for (final note in sample.allNotes) {
        expect(
          [for (final l in note.lines) l.n],
          List.generate(note.lines.length, (i) => i + 1),
          reason: note.id,
        );
      }
    });

    test('uses the decision-format section types', () {
      final types = {
        for (final s in sample.allNotes.expand((n) => n.sections)) s.type,
      };
      expect(types, containsAll(['scene', 'rules', 'traps', 'worked']));
      expect(
        types.difference({
          'scene', 'rules', 'notice', 'actions', 'why', 'traps', 'numbers',
          'worked', //
        }),
        isEmpty,
      );
    });

    test('"notes" lines have refs to real pages; practice lines may not', () {
      for (final note in sample.allNotes) {
        for (final line in note.lines) {
          expect(line.basis, anyOf('notes', 'practice'));
          if (line.isPractice && line.ref.isEmpty) continue;
          final refs = parseRefs(line.ref);
          expect(refs, isNotEmpty, reason: '${note.id} line ${line.n}');
          for (final r in refs) {
            expect(
              r.page,
              inInclusiveRange(1, sample.sources[r.sourceKey]!.pages),
              reason: '${note.id} line ${line.n}: ${line.ref}',
            );
          }
        }
      }
    });
  });

  group('reader with the sample notes', () {
    late Box uiBox;
    setUp(() async => uiBox = await Hive.openBox('ui', bytes: Uint8List(0)));
    tearDown(() => uiBox.close());

    for (final note in sample.allNotes) {
      testWidgets('${note.id}: every section renders, worked box, no refs', (
        tester,
      ) async {
        // Tall enough that the whole note is built.
        tester.view.physicalSize = const Size(800, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              courseProvider.overrideWith((ref, id) => sample),
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

        // The practice question sits in its tinted box, with its lines.
        final box = find.byKey(const ValueKey('worked-box'));
        expect(box, findsOneWidget);
        final worked = note.sections.firstWhere((s) => s.type == 'worked');
        for (final line in worked.lines) {
          expect(
            find.descendant(of: box, matching: find.text(line.text)),
            findsOneWidget,
          );
        }

        // Only text, titles and numbers: no refs, tags or flag boxes.
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
