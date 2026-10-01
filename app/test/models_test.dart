import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/ref_parser.dart';
import 'package:gonurse/models/course.dart';

void main() {
  final course = Course.fromJson(jsonDecode(
          File('../content/pharmacology_notes.json').readAsStringSync())
      as Map<String, dynamic>);

  test('8 units and 141 notes', () {
    expect(course.units.length, 8);
    expect(course.noteCount, 141);
    expect(course.notesById.length, 141, reason: 'note IDs are unique');
  });

  test('every link resolves to a note', () {
    for (final note in course.allNotes) {
      for (final link in note.links) {
        expect(course.notesById, contains(link), reason: '${note.id} -> $link');
      }
    }
  });

  test('line numbers run 1..N through each note', () {
    for (final note in course.allNotes) {
      expect([for (final l in note.lines) l.n],
          List.generate(note.lines.length, (i) => i + 1),
          reason: note.id);
    }
  });

  test('every ref parses to a known source and a page in range', () {
    for (final line in course.allNotes.expand((n) => n.lines)) {
      if (line.ref.isEmpty) continue;
      final refs = parseRefs(line.ref);
      expect(refs, isNotEmpty, reason: line.ref);
      for (final r in refs) {
        final source = course.sources[r.sourceKey];
        expect(source, isNotNull, reason: line.ref);
        expect(r.page, inInclusiveRange(1, source!.pages), reason: line.ref);
      }
    }
  });

  test('section types are known', () {
    const known = {'big_idea', 'how', 'patient', 'facts', 'trap'};
    for (final s in course.allNotes.expand((n) => n.sections)) {
      expect(known, contains(s.type));
    }
  });

  test('slide sources map to PDF file names', () {
    expect(course.sources['Gen slide']!.pdfFile, 'general pharmacology-1.pdf');
    expect(course.sources['CVS p.']!.pdfFile, 'CVS pharmacology (1).pdf');
  });
}
