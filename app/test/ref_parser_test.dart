import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/data/ref_parser.dart';

void main() {
  List<(String, int)> pages(String ref) =>
      [for (final r in parseRefs(ref)) (r.sourceKey, r.page)];

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
    expect(pages('CVS p.96-97, RCVS p.116'), [('CVS p.', 96), ('RCVS p.', 116)]);
  });

  test('slides, with trailing words', () {
    expect(pages('GI slide 14 notes'), [('GI slide', 14)]);
    expect(pages('Gen slide 77'), [('Gen slide', 77)]);
  });

  test('labels', () {
    expect([for (final r in parseRefs('CVS p.96-97, RCVS p.116')) r.label],
        ['CVS p.96-97', 'RCVS p.116']);
    expect([for (final r in parseRefs('Gen slide 77')) r.label], ['Gen slide 77']);
  });

  test('CVS does not match inside RCVS', () {
    expect(pages('RCVS p.5'), [('RCVS p.', 5)]);
  });
}
