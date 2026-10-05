import 'package:flutter/material.dart';

import '../../data/ref_parser.dart';
import '../../models/course.dart';

/// Long-press menu for a line: "Open in my notes", one entry per reference.
/// Choosing one opens that source file at the reference's first page.
Future<void> openRefs(
  BuildContext context,
  Course course,
  List<SourceRef> refs,
) async {
  if (refs.isEmpty) return;
  final ref = await showModalBottomSheet<SourceRef>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in refs)
            ListTile(
              minTileHeight: 60,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(
                refs.length == 1
                    ? 'Open in my notes'
                    : 'Open in my notes · ${r.label}',
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text(_where(course.sources[r.sourceKey], r)),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    ),
  );
  if (ref == null || !context.mounted) return;
  _openSource(context, course, ref);
}

/// e.g. "CVS pharmacology (1).pdf · page 97" or "… · slide 14".
String _where(Source? source, SourceRef ref) {
  if (source == null) return ref.label;
  return '${source.pdfFile} · ${source.isSlide ? 'slide' : 'page'} ${ref.page}';
}

void _openSource(BuildContext context, Course course, SourceRef ref) {
  // TODO(step 6): open the bundled PDF in the viewer.
  final file = course.sources[ref.sourceKey]?.pdfFile ?? ref.sourceKey;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('PDF viewer comes in step 6: $file, page ${ref.page}'),
    ),
  );
}
