import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/ref_parser.dart';
import 'package:gonurse/models/course.dart';

Course load(String id) => Course.fromJson(
  jsonDecode(File('../content/${id}_notes.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final courseIds =
      (jsonDecode(File('../content/version.json').readAsStringSync())
              as Map<String, dynamic>)
          .keys
          .toList();

  test('version.json lists both courses, each with a notes file', () {
    expect(courseIds, ['pharmacology', 'medsurg']);
    for (final id in courseIds) {
      expect(File('../content/${id}_notes.json').existsSync(), isTrue);
    }
  });

  test('Pharmacology: 8 units, 51 notes', () {
    final course = load('pharmacology');
    expect(course.units.length, 8);
    expect(course.noteCount, 51);
  });

  test('Medical-Surgical: 6 units, 47 notes', () {
    final course = load('medsurg');
    expect(course.course, 'Medical-Surgical Nursing');
    expect(course.units.length, 6);
    expect(course.noteCount, 47);
  });

  for (final id in courseIds) {
    group(id, () {
      final course = load(id);

      test('note IDs are unique', () {
        expect(course.notesById.length, course.noteCount);
      });

      test('every link resolves to a note', () {
        for (final note in course.allNotes) {
          for (final link in note.links) {
            expect(
              course.notesById,
              contains(link),
              reason: '${note.id} -> $link',
            );
          }
        }
      });

      test('line numbers run 1..N through each note', () {
        for (final note in course.allNotes) {
          expect(
            [for (final l in note.lines) l.n],
            List.generate(note.lines.length, (i) => i + 1),
            reason: note.id,
          );
        }
      });

      test('every "notes" line has a ref to a known source and a page in '
          'range', () {
        for (final line in course.allNotes.expand((n) => n.lines)) {
          expect(line.basis, anyOf('notes', 'practice'));
          if (line.isPractice && line.ref.isEmpty) continue;
          final refs = parseRefs(line.ref, course.sources.keys);
          expect(refs, isNotEmpty, reason: line.ref);
          for (final r in refs) {
            expect(
              r.page,
              inInclusiveRange(1, course.sources[r.sourceKey]!.pages),
              reason: line.ref,
            );
          }
        }
      });

      test('section types are known', () {
        const known = {
          'big_idea', 'how', 'patient', 'facts', 'trap', // original format
          'scene', 'rules', 'notice', 'actions', 'why', 'traps', 'numbers',
          'worked', // decision format
        };
        for (final s in course.allNotes.expand((n) => n.sections)) {
          expect(known, contains(s.type));
        }
      });
    });
  }

  test('slide sources map to PDF file names; "slides" counts as slides', () {
    final pharm = load('pharmacology');
    expect(pharm.sources['Gen slide']!.pdfFile, 'general pharmacology-1.pdf');
    expect(pharm.sources['CVS p.']!.pdfFile, 'CVS pharmacology (1).pdf');
    final medsurg = load('medsurg');
    expect(medsurg.sources['Burns slide']!.isSlide, isTrue); // kind "slides"
    expect(medsurg.sources['Mal p.']!.isSlide, isFalse); // kind "book"
  });

  test(
    'bedside format: new types, basis, and practice lines without a ref',
    () {
      final note = Note.fromJson(const {
        'id': 'x',
        'title': 'X',
        'path': ['U', 'T'],
        'sections': [
          {
            'type': 'scene',
            'title': "The patient you'll meet",
            'lines': [
              {'n': 1, 'text': 'An older patient.', 'ref': 'CVS p.96'},
            ],
          },
          {
            'type': 'actions',
            'title': 'What the nurse does',
            'lines': [
              {
                'n': 2,
                'text': 'Check apical pulse.',
                'ref': '',
                'basis': 'practice',
              },
              {
                'n': 3,
                'text': 'Hold the dose.',
                'ref': 'CVS p.100',
                'basis': 'notes',
              },
            ],
          },
        ],
      });
      expect([for (final l in note.lines) l.isPractice], [false, true, false]);
      expect(note.lines.first.basis, 'notes', reason: 'default when missing');
      expect(note.links, isEmpty);
      expect(note.flags, isEmpty);
    },
  );
}
