import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/data/ref_parser.dart';
import 'package:gonurse/features/pdf/pdf_screen.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Course load(String id) => Course.fromJson(
    jsonDecode(File('../content/${id}_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final courses = {
    for (final id
        in (jsonDecode(File('../content/version.json').readAsStringSync())
                as Map<String, dynamic>)
            .keys)
      id: load(id),
  };
  final course = courses['pharmacology']!;

  test('every source file of every course is bundled as a PDF', () async {
    expect(courses.keys, containsAll(['pharmacology', 'medsurg', 'obgyn']));
    for (final c in courses.values) {
      for (final source in c.sources.values) {
        final bytes = await rootBundle.load(
          '$sourceFilesAssetDir${source.pdfFile}',
        );
        expect(
          ascii.decode(bytes.buffer.asUint8List(0, 5)),
          '%PDF-',
          reason: '${c.course}: ${source.pdfFile}',
        );
      }
    }
  });

  group('viewer', () {
    late Box uiBox;
    late List<(String, int)> shown;
    late ValueChanged<int> turnPage;

    setUp(() async {
      uiBox = await Hive.openBox('ui', bytes: Uint8List(0));
      shown = [];
    });
    tearDown(() => uiBox.close());

    // Stands in for pdfrx, which needs PDFium (not available in tests).
    Widget fakePdfView({
      required String asset,
      required int initialPage,
      required ValueChanged<int> onPageChanged,
    }) {
      shown.add((asset, initialPage));
      turnPage = onPageChanged;
      return const Center(child: Text('PDF'));
    }

    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseProvider.overrideWith((ref, id) => courses[id]),
            uiBoxProvider.overrideWithValue(uiBox),
            pdfViewBuilderProvider.overrideWithValue(fakePdfView),
          ],
          child: MaterialApp(home: home),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('"Open in my notes" opens the right file at the right page, '
        'and Back returns to the note', (tester) async {
      await pump(
        tester,
        const ReaderScreen(courseId: 'pharmacology', noteId: 'v2-digoxin'),
      );
      final line1 = course.notesById['v2-digoxin']!.lines.first;
      await tester.longPress(find.text(line1.text));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in my notes · CVS p.98'));
      await tester.pumpAndSettle();

      expect(shown.last, (
        '${sourceFilesAssetDir}CVS pharmacology (1).pdf',
        98,
      ));
      expect(find.text('CVS pharmacology (1).pdf'), findsOneWidget);
      expect(find.text('Page 98 of 159'), findsOneWidget);

      turnPage(99);
      await tester.pump();
      expect(find.text('Page 99 of 159'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(line1.text), findsOneWidget);
      expect((uiBox.get('last_note') as Map)['note'], 'v2-digoxin');
    });

    // Each course's refs open that course's files.
    for (final (courseId, key, file, unit) in [
      ('medsurg', 'Mal p.', 'Malaria Case Management Manual 2022.pdf', 'Page'),
      ('medsurg', 'Burns slide', 'Burns.pdf', 'Slide'),
      (
        'medsurg',
        'CVS slide',
        'Unit III. Cardiovascular Disorders B.pdf',
        'Slide',
      ),
      ('obgyn', 'OG slide', 'Obstetrics and Gynecology Nursing.pdf', 'Slide'),
    ]) {
      testWidgets('$courseId "$key" ref opens $file', (tester) async {
        final course = courses[courseId]!;
        // A line whose only ref is to this source.
        final (note, line, ref) = [
          for (final n in course.allNotes)
            for (final l in n.lines)
              if (parseRefs(l.ref, course.sources.keys) case [
                final r,
              ] when r.sourceKey == key)
                (n, l, r),
        ].first;

        await pump(tester, ReaderScreen(courseId: courseId, noteId: note.id));
        await tester.scrollUntilVisible(
          find.text(line.text),
          300,
          scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        );
        await tester.longPress(find.text(line.text));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open in my notes'));
        await tester.pumpAndSettle();

        expect(shown.last, ('$sourceFilesAssetDir$file', ref.page));
        expect(find.text(file), findsOneWidget);
        expect(
          find.text('$unit ${ref.page} of ${course.sources[key]!.pages}'),
          findsOneWidget,
        );
      });
    }

    testWidgets('slide decks open the converted PDF at slide N', (
      tester,
    ) async {
      final gen = course.sources['Gen slide']!;
      await pump(tester, PdfScreen(source: gen, page: 77));
      expect(shown.last, (
        '${sourceFilesAssetDir}general pharmacology-1.pdf',
        77,
      ));
      expect(find.text('general pharmacology-1.pdf'), findsOneWidget);
      expect(find.text('Slide 77 of 132'), findsOneWidget);
    });

    testWidgets('a page past the end opens the last page', (tester) async {
      final derm = course.sources['Derm p.']!;
      await pump(tester, PdfScreen(source: derm, page: 500));
      expect(shown.last.$2, derm.pages);
    });
  });
}
