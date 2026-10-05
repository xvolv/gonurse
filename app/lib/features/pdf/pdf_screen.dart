import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../config.dart';
import '../../models/course.dart';

/// Builds the PDF view. A provider so widget tests (which have no PDFium)
/// can replace it.
typedef PdfViewBuilder =
    Widget Function({
      required String asset,
      required int initialPage,
      required ValueChanged<int> onPageChanged,
    });

final pdfViewBuilderProvider = Provider<PdfViewBuilder>((ref) => _pdfrxView);

Widget _pdfrxView({
  required String asset,
  required int initialPage,
  required ValueChanged<int> onPageChanged,
}) {
  return PdfViewer.asset(
    asset,
    initialPageNumber: initialPage,
    params: PdfViewerParams(
      backgroundColor: Colors.grey.shade300,
      onPageChanged: (page) {
        if (page != null) onPageChanged(page);
      },
      loadingBannerBuilder: (context, _, _) =>
          const Center(child: CircularProgressIndicator()),
      errorBannerBuilder: (context, error, _, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not open this file.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

/// One of her source files (bundled with the app), opened at [page].
/// Back returns to the note exactly where she was.
class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({super.key, required this.source, required this.page});

  final Source source;
  final int page;

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> {
  late int _page = _firstPage;

  int get _firstPage => widget.page.clamp(1, widget.source.pages);

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final unit = source.isSlide ? 'Slide' : 'Page';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.pdfFile,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '$unit $_page of ${source.pages}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ref.watch(pdfViewBuilderProvider)(
        asset: '$sourceFilesAssetDir${source.pdfFile}',
        initialPage: _firstPage,
        onPageChanged: (page) {
          if (mounted && page != _page) setState(() => _page = page);
        },
      ),
    );
  }
}
