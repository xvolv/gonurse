import 'package:flutter/material.dart';

import '../../data/ref_parser.dart';
import '../../models/course.dart';

/// Opens the source file of [refs] at its first page. With several refs she
/// picks one from a small menu first.
Future<void> openRefs(
  BuildContext context,
  Course course,
  List<SourceRef> refs,
) async {
  if (refs.isEmpty) return;
  final ref = refs.length == 1
      ? refs.single
      : await showModalBottomSheet<SourceRef>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in refs)
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(r.label),
                    subtitle: Text(course.sources[r.sourceKey]?.pdfFile ?? ''),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
            ),
          ),
        );
  if (ref == null || !context.mounted) return;
  _openSource(context, course, ref);
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
