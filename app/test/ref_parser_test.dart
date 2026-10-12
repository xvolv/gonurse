import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/ref_parser.dart';

/// Source keys come from each course's own `sources` block.
Iterable<String> keysOf(String file) =>
    ((jsonDecode(File('../content/$file').readAsStringSync())
                as Map<String, dynamic>)['sources']
            as Map<String, dynamic>)
        .keys;

void main() {
  final pharmacology = keysOf('pharmacology_notes.json');
  final medsurg = keysOf('medsurg_notes.json');

  List<(String, int)> pages(String ref, [Iterable<String>? keys]) => [
    for (final r in parseRefs(ref, keys ?? pharmacology)) (r.sourceKey, r.page),
  ];

  test('single page', () {
    expect(pages('CVS p.97'), [('CVS p.', 97)]);
  });

  test('bare number after comma belongs to previous key', () {
    expect(pages('RCVS p.117, 119'), [('RCVS p.', 117), ('RCVS p.', 119)]);
    expect(pages('CNS-sum p.42, 44'), [('CNS-sum p.', 42), ('CNS-sum p.', 44)]);
  });

  test('two different sources', () {
    expect(pages('CVS p.24, RCVS p.12'), [('CVS p.', 24), ('RCVS p.', 12)]);
  });

  test('range opens at first page', () {
    expect(pages('CVS p.96-97, RCVS p.116'), [
      ('CVS p.', 96),
      ('RCVS p.', 116),
    ]);
  });

  test('slides, with trailing words', () {
    expect(pages('GI slide 14 notes'), [('GI slide', 14)]);
    expect(pages('Gen slide 77'), [('Gen slide', 77)]);
  });

  test('labels', () {
    expect(
      [
        for (final r in parseRefs('CVS p.96-97, RCVS p.116', pharmacology))
          r.label,
      ],
      ['CVS p.96-97', 'RCVS p.116'],
    );
    expect(
      [for (final r in parseRefs('Gen slide 77', pharmacology)) r.label],
      ['Gen slide 77'],
    );
  });

  test('CVS does not match inside RCVS', () {
    expect(pages('RCVS p.5'), [('RCVS p.', 5)]);
  });

  group('Medical-Surgical keys', () {
    test('slides and book pages', () {
      expect(pages('CVS slide 98', medsurg), [('CVS slide', 98)]);
      expect(pages('Mal p. 47', medsurg), [('Mal p.', 47)]);
      expect(pages('Burns slide 27', medsurg), [('Burns slide', 27)]);
      expect(pages('Men2 slide 12, Men slide 4', medsurg), [
        ('Men2 slide', 12),
        ('Men slide', 4),
      ]);
      expect(pages('RespD slide 31-33', medsurg), [('RespD slide', 31)]);
    });

    test('labels', () {
      expect(
        [
          for (final r in parseRefs('Mal p. 47, Burns slide 27', medsurg))
            r.label,
        ],
        ['Mal p.47', 'Burns slide 27'],
      );
    });

    test("one course's keys don't match another's refs", () {
      expect(pages('CVS slide 98', pharmacology), isEmpty);
      expect(pages('CVS p.97', medsurg), isEmpty);
    });
  });

  test('no keys or an empty ref gives nothing', () {
    expect(parseRefs('CVS p.97', const []), isEmpty);
    expect(parseRefs('', pharmacology), isEmpty);
  });
}
