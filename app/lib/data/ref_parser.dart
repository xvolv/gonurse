/// Parses a line's `ref` string, e.g. `"CVS p.96-97, RCVS p.116"`, into
/// references that can be opened in a source PDF.
library;

class SourceRef {
  /// A key from the course's `sources`, e.g. `CVS p.`.
  final String sourceKey;

  /// First page (or slide) of the reference; this is where we open the PDF.
  final int page;

  /// The text shown to the user, e.g. `CVS p.96-97`.
  final String label;

  const SourceRef(this.sourceKey, this.page, this.label);

  @override
  bool operator ==(Object other) =>
      other is SourceRef && other.sourceKey == sourceKey && other.page == page;

  @override
  int get hashCode => Object.hash(sourceKey, page);

  @override
  String toString() => 'SourceRef($sourceKey, $page)';
}

final _refPattern = RegExp(
  r'(Gen slide|Gen p\.|ANS p\.|CNS slide|CNS-sum p\.|RCVS p\.|CVS p\.|GI slide|TB slide|Contra p\.|Derm p\.)\s*([\d\-–, ]+)',
);

/// One [SourceRef] per page number or range. A bare number after a comma belongs
/// to the previous key: `"RCVS p.117, 119"` gives RCVS pages 117 and 119.
List<SourceRef> parseRefs(String ref) {
  final result = <SourceRef>[];
  for (final m in _refPattern.allMatches(ref)) {
    final key = m.group(1)!;
    for (final part in m.group(2)!.split(',')) {
      final range = part.trim();
      if (range.isEmpty) continue;
      final first = int.tryParse(range.split(RegExp('[-–]')).first.trim());
      if (first == null) continue;
      final keyLabel = key.endsWith('.') ? key : '$key ';
      result.add(SourceRef(key, first, '$keyLabel$range'));
    }
  }
  return result;
}
