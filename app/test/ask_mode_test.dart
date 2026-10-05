import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/features/ask/ask_action.dart';
import 'package:gonurse/features/ask/prompt_templates.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

void main() {
  final course = Course.fromJson(
    jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final digoxin = course.notesById['digoxin']!;

  group('templates', () {
    test('fills topic and text', () {
      final prompt = fillTemplate(
        'T: {topic}\nX: "{text}"',
        topic: 'A',
        text: 'B',
      );
      expect(prompt, 'T: A\nX: "B"');
    });

    test('the default Amharic template gets title, breadcrumb and line', () {
      final prompt = buildPrompt(
        AskMode.explain.defaultTemplate,
        course,
        digoxin,
        digoxin.lines.first,
      );
      expect(prompt, startsWith('I am a nursing student in Ethiopia'));
      expect(prompt, contains('Explain the text below in simple Amharic.'));
      expect(
        prompt,
        contains(
          'Topic: Digoxin (Pharmacology › Renal & Cardiovascular › Heart failure)',
        ),
      );
      expect(prompt, endsWith('Text: "${digoxin.lines.first.text}"'));
    });

    test('line text is capped at 1000 characters', () {
      final prompt = fillTemplate('"{text}"', topic: '', text: 'a' * 1500);
      expect(prompt, '"${'a' * 1000}"');
      final exact = fillTemplate('{text}', topic: '', text: 'b' * 1000);
      expect(exact.length, 1000);
    });

    test('the cap does not split a character made of several code units', () {
      final text = '${'a' * 999}Na⁺👍🏽 more';
      final prompt = fillTemplate('{text}', topic: '', text: text);
      expect(prompt, '${'a' * 999}N');
    });

    test('practice lines (no ref) build a prompt like any other line', () {
      const line = Line(
        n: 2,
        text: 'Check apical pulse.',
        ref: '',
        basis: 'practice',
      );
      expect(
        buildPrompt('{text}', course, digoxin, line),
        'Check apical pulse.',
      );
    });
  });

  group('ask mode', () {
    late Box uiBox;
    late List<Uri> opened;
    String? clipboard;
    var clipboardFails = false;

    setUp(() async {
      uiBox = await Hive.openBox('ui', bytes: Uint8List(0));
      opened = [];
      clipboard = null;
      clipboardFails = false;
    });
    tearDown(() => uiBox.close());

    Future<void> pumpReader(WidgetTester tester) async {
      // Phone-sized: only part of the note fits on screen.
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) throw PlatformException(code: 'no-clipboard');
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseProvider.overrideWith((ref, id) => course),
            uiBoxProvider.overrideWithValue(uiBox),
            urlOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: const MaterialApp(
            home: ReaderScreen(courseId: 'pharmacology', noteId: 'digoxin'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> startAsking(WidgetTester tester) async {
      await tester.tap(find.text('Ask AI'));
      await tester.pumpAndSettle();
    }

    Finder badge(int i) => find.byKey(ValueKey('ask-badge-$i'));

    int badgeCount() {
      var n = 0;
      while (badge(n + 1).evaluate().isNotEmpty) {
        n++;
      }
      return n;
    }

    testWidgets(
      'badges only on visible lines, numbered from 1, at least 40dp',
      (tester) async {
        await pumpReader(tester);
        expect(badge(1), findsNothing);
        await startAsking(tester);

        final count = badgeCount();
        expect(count, greaterThan(0));
        expect(
          count,
          lessThan(digoxin.lines.length),
          reason: 'some lines are off screen',
        );
        for (var i = 1; i <= count; i++) {
          final size = tester.getSize(badge(i));
          expect(size.width, greaterThanOrEqualTo(40));
          expect(size.height, greaterThanOrEqualTo(40));
        }
        expect(find.text('Explain in Amharic'), findsOneWidget);
        expect(find.text('Simpler'), findsOneWidget);
        expect(find.text('Quiz me'), findsOneWidget);
        expect(find.text('Ask AI'), findsNothing);

        // After scrolling, numbering restarts at 1 on the lines now visible.
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(badge(1), findsOneWidget);
        await tester.tap(badge(1));
        await tester.pumpAndSettle();
        expect(clipboard, isNot(contains(digoxin.lines.first.text)));

        // Cancel leaves Ask mode.
        await startAsking(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(badge(1), findsNothing);
        expect(find.text('Ask AI'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a badge copies the prompt, saves the line, opens DeepSeek',
      (tester) async {
        await pumpReader(tester);
        await startAsking(tester);
        await tester.tap(badge(1));
        await tester.pump();

        final line = digoxin.lines.first;
        expect(
          clipboard,
          buildPrompt(AskMode.explain.defaultTemplate, course, digoxin, line),
        );
        expect(opened, [Uri.parse(deepSeekUrl)]);
        expect(find.text(copiedToast), findsOneWidget);
        expect(uiBox.get('ask_pending'), {'note': 'digoxin', 'n': line.n});
        await tester.pumpAndSettle();
        expect(badge(1), findsNothing, reason: 'Ask mode ends');
      },
    );

    testWidgets('the selected mode picks the template', (tester) async {
      await pumpReader(tester);
      await startAsking(tester);
      await tester.tap(find.text('Quiz me'));
      await tester.pumpAndSettle();
      await tester.tap(badge(1));
      await tester.pumpAndSettle();
      expect(
        clipboard,
        startsWith(AskMode.quiz.defaultTemplate.split('\n').first),
      );
      expect(
        clipboard,
        contains('Ask me 3 exam-style multiple-choice questions'),
      );
    });

    testWidgets(
      'coming back to the app highlights the line for about 2 seconds',
      (tester) async {
        await pumpReader(tester);
        await startAsking(tester);
        await tester.tap(badge(1));
        await tester.pumpAndSettle();

        Color? lineColor() {
          final box = tester.widget<AnimatedContainer>(
            find.ancestor(
              of: find.text(digoxin.lines.first.text),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return (box.decoration as BoxDecoration).color;
        }

        final highlight = Theme.of(
          tester.element(find.byType(ReaderScreen)),
        ).colorScheme.primaryContainer;
        expect(lineColor(), isNot(highlight));

        // Windows: focus flickers back to the app while the browser opens.
        // That is not her returning; keep the highlight for later.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(lineColor(), isNot(highlight));
        expect(uiBox.get('ask_pending'), isNotNull);
        await tester.pump(const Duration(seconds: 30)); // she reads DeepSeek

        // She goes to DeepSeek and comes back.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(lineColor(), highlight);
        expect(uiBox.get('ask_pending'), isNull, reason: 'shown once');

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(lineColor(), isNot(highlight));
      },
    );

    testWidgets('if the clipboard fails, a dialog shows the prompt to copy', (
      tester,
    ) async {
      await pumpReader(tester);
      clipboardFails = true;
      await startAsking(tester);
      await tester.tap(badge(1));
      await tester.pumpAndSettle();

      final prompt = buildPrompt(
        AskMode.explain.defaultTemplate,
        course,
        digoxin,
        digoxin.lines.first,
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        prompt,
      );
      expect(opened, isEmpty);

      clipboardFails = false;
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, prompt);
      expect(find.byType(SelectableText), findsNothing);
      expect(opened, [Uri.parse(deepSeekUrl)]);
    });
  });
}
