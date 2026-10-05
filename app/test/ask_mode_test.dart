import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/features/ask/ai_target.dart';
import 'package:gonurse/features/ask/ask_action.dart';
import 'package:gonurse/features/ask/ask_button.dart';
import 'package:gonurse/features/ask/prompt_templates.dart';
import 'package:gonurse/features/reader/reader_screen.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

void main() {
  final course = Course.fromJson(
    jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final digoxin = course.notesById['v2-digoxin']!;
  Line line(int n) => digoxin.lines[n - 1];

  group('templates', () {
    test('fills topic and text', () {
      final prompt = fillTemplate(
        'T: {topic}\nX: "{text}"',
        topic: 'A',
        text: 'B',
      );
      expect(prompt, 'T: A\nX: "B"');
    });

    test('Amharic template: several lines numbered, in note order', () {
      final prompt = buildPrompt(
        AskMode.explain.defaultTemplate,
        course,
        digoxin,
        [line(3), line(1)], // selected in this order
      );
      expect(
        prompt,
        startsWith(
          'በአማርኛ ብቻ መልስ። (Reply ONLY in Amharic, in Ge\'ez script. '
          'Not English, not Tigrinya, not any other language.)\n\n'
          'I am a nursing student preparing for the Ethiopian national '
          'nursing exit exam.',
        ),
      );
      expect(prompt, contains('- Explain each line by its number.\n'));
      expect(
        prompt,
        endsWith(
          'Text:\n1. ${line(1).text}\n2. ${line(3).text}\n\n'
          'አስታውስ፦ መልሱ በሙሉ በአማርኛ ይሁን። '
          '(Reminder: the entire answer must be in Amharic.)',
        ),
      );
      expect(prompt, isNot(contains('{')), reason: 'no placeholder left');
    });

    test('templates with {topic} get the note title and breadcrumb', () {
      final prompt = buildPrompt(
        AskMode.simpler.defaultTemplate,
        course,
        digoxin,
        [line(1)],
      );
      expect(
        prompt,
        contains(
          'Topic: Is this digoxin toxicity? What do you do? '
          '(Pharmacology › Renal & Cardiovascular › Heart failure)',
        ),
      );
    });

    test('every note, all lines selected: the ChatGPT link stays under '
        '6,000 characters', () {
      for (final note in course.allNotes) {
        final prompt = buildPrompt(
          AskMode.explain.defaultTemplate,
          course,
          note,
          note.lines,
        );
        final link = AiTarget.chatGpt.uriFor(prompt).toString();
        expect(AiTarget.chatGpt.prefills(prompt), isTrue, reason: note.id);
        expect(link.length, lessThanOrEqualTo(6000), reason: note.id);
      }
    });

    test('1,500 characters of note-style text (with →, ⁺, β) stay under '
        '6,000; 1,500 Amharic letters do not and fall back to paste', () {
      String link(String text) => AiTarget.chatGpt
          .uriFor(
            fillTemplate(
              AskMode.explain.defaultTemplate,
              topic: '',
              text: text,
            ),
          )
          .toString();

      final english = joinLines([
        for (var i = 0; i < 40; i++) 'Low K⁺ → toxic dose; β-blocker ok.',
      ]);
      expect(english.length, greaterThan(1400));
      expect(link(english).length, lessThanOrEqualTo(6000));

      // Each Ge'ez letter is 3 bytes = 9 characters in a link.
      final amharic = 'ሀ' * 1500;
      final encoded = Uri.encodeComponent(
        fillTemplate(AskMode.explain.defaultTemplate, topic: '', text: amharic),
      );
      expect(encoded.length, greaterThan(6000));
      expect(link(amharic), chatGptUrl, reason: 'plain link: she pastes');
      expect(
        AiTarget.chatGpt.prefills(
          fillTemplate(
            AskMode.explain.defaultTemplate,
            topic: '',
            text: amharic,
          ),
        ),
        isFalse,
      );
    });

    test('one line is sent as it is', () {
      final prompt = buildPrompt('{text}', course, digoxin, [line(2)]);
      expect(prompt, line(2).text);
    });

    test('combined text is capped at 1,500 characters at a line boundary', () {
      final text = joinLines(['a' * 600, 'b' * 600, 'c' * 600]);
      expect(text, '1. ${'a' * 600}\n2. ${'b' * 600}\n…');
      expect(text.length, lessThanOrEqualTo(maxPromptTextLength + 2));
    });

    test('a single line longer than the cap is cut inside the line', () {
      expect(joinLines(['x' * 2000]), '${'x' * 1500}\n…');
    });

    test('the cap does not split a character made of several code units', () {
      final text = joinLines(['${'a' * 1499}👍🏽 more']);
      expect(text, '${'a' * 1499}👍🏽\n…');
    });
  });

  group('selecting lines', () {
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

    Future<void> pumpReader(WidgetTester tester, {AiTarget? ai}) async {
      if (ai != null) uiBox.put('ai_target', ai.name);
      // Phone-wide and tall enough that the whole note is built.
      tester.view.physicalSize = const Size(420, 5000);
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
            home: ReaderScreen(courseId: 'pharmacology', noteId: 'v2-digoxin'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> doubleTap(WidgetTester tester, int n) async {
      final f = find.text(line(n).text);
      // Lines far down the note are only built once scrolled to.
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    BoxDecoration decoration(WidgetTester tester, int n) =>
        tester
                .widget<AnimatedContainer>(find.byKey(ValueKey('line-$n')))
                .decoration!
            as BoxDecoration;

    bool isSelected(WidgetTester tester, int n) =>
        (decoration(tester, n).border! as Border).left.color.a > 0;

    AskAiButton askButton(WidgetTester tester) =>
        tester.widget<AskAiButton>(find.byType(AskAiButton));

    Badge badge(WidgetTester tester) => tester.widget<Badge>(
      find.descendant(
        of: find.byType(AskAiButton),
        matching: find.byType(Badge),
      ),
    );

    testWidgets('double-tap selects, double-tap again unselects; '
        'single tap does nothing', (tester) async {
      await pumpReader(tester);
      await tester.tap(find.text(line(2).text));
      await tester.pumpAndSettle();
      expect(isSelected(tester, 2), isFalse);

      await doubleTap(tester, 2);
      expect(isSelected(tester, 2), isTrue);
      await doubleTap(tester, 2);
      expect(isSelected(tester, 2), isFalse);
    });

    testWidgets('practice-question lines can be selected too', (tester) async {
      await pumpReader(tester);
      final option = digoxin.lines.firstWhere(
        (l) => l.text.startsWith('a. ') && l.isPractice,
      );
      await doubleTap(tester, option.n);
      expect(isSelected(tester, option.n), isTrue);
    });

    testWidgets('the AI button is greyed out until lines are selected, '
        'then shows how many; × clears', (tester) async {
      await pumpReader(tester);
      expect(askButton(tester).count, 0);
      expect(badge(tester).isLabelVisible, isFalse);
      expect(find.byKey(const ValueKey('clear-selection')), findsNothing);

      // Tapping it with nothing selected sends nothing.
      await tester.tap(find.byType(AskAiButton));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      await doubleTap(tester, 1);
      await doubleTap(tester, 3);
      expect(askButton(tester).count, 2);
      expect(badge(tester).isLabelVisible, isTrue);
      expect((badge(tester).label! as Text).data, '2');

      await tester.tap(find.byKey(const ValueKey('clear-selection')));
      await tester.pumpAndSettle();
      expect(askButton(tester).count, 0);
      expect(isSelected(tester, 1), isFalse);
      expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    });

    testWidgets('tap sends all selected lines in note order to ChatGPT, '
        'copies them, and clears the selection', (tester) async {
      await pumpReader(tester);
      await doubleTap(tester, 3);
      await doubleTap(tester, 1);
      await tester.tap(find.byType(AskAiButton));
      await tester.pump();

      final prompt = buildPrompt(
        AskMode.explain.defaultTemplate,
        course,
        digoxin,
        [line(1), line(3)],
      );
      expect(prompt, contains('Text:\n1. ${line(1).text}\n2. ${line(3).text}'));
      expect(clipboard, prompt, reason: 'backup copy');
      expect(opened.single.host, 'chatgpt.com');
      expect(opened.single.queryParameters['q'], prompt);
      expect(find.text(AiTarget.chatGpt.openedToast!), findsOneWidget);
      expect(uiBox.get('ask_pending'), {
        'note': 'v2-digoxin',
        'lines': [1, 3],
      });
      await tester.pumpAndSettle();
      expect(askButton(tester).count, 0);
      expect(isSelected(tester, 1), isFalse);
    });

    testWidgets('long-press the AI button: the chosen mode is used once', (
      tester,
    ) async {
      await pumpReader(tester);
      await doubleTap(tester, 2);
      await tester.longPress(find.byType(AskAiButton));
      await tester.pumpAndSettle();
      expect(find.text('Explain in Amharic'), findsOneWidget);
      expect(find.text('Simpler'), findsOneWidget);
      await tester.tap(find.text('Quiz me'));
      await tester.pumpAndSettle();
      expect(clipboard, contains('ONLY\nclinical scenario questions'));
      expect(clipboard, contains(line(2).text));

      // The next plain tap is back to "Explain in Amharic".
      await doubleTap(tester, 2);
      await tester.tap(find.byType(AskAiButton));
      await tester.pumpAndSettle();
      expect(clipboard, startsWith('በአማርኛ ብቻ መልስ።'));
    });

    testWidgets('a link over 6,000 characters falls back to copy + paste', (
      tester,
    ) async {
      uiBox.put('prompt_explain', '${'x' * 6000}\n{text}');
      await pumpReader(tester);
      await doubleTap(tester, 1);
      await tester.tap(find.byType(AskAiButton));
      await tester.pump();
      expect(opened, [Uri.parse(chatGptUrl)]);
      expect(clipboard, endsWith(line(1).text));
      expect(find.text(AiTarget.chatGpt.copiedToast), findsOneWidget);
    });

    testWidgets('with DeepSeek chosen: same selection, copy and open', (
      tester,
    ) async {
      await pumpReader(tester, ai: AiTarget.deepSeek);
      await doubleTap(tester, 2);
      await doubleTap(tester, 1);
      await tester.tap(find.byType(AskAiButton));
      await tester.pump();
      expect(
        clipboard,
        buildPrompt(AskMode.explain.defaultTemplate, course, digoxin, [
          line(1),
          line(2),
        ]),
      );
      expect(opened, [Uri.parse(deepSeekUrl)]);
      expect(find.text(AiTarget.deepSeek.copiedToast), findsOneWidget);
    });

    testWidgets('swiping to another note clears the selection', (tester) async {
      await pumpReader(tester);
      await doubleTap(tester, 1);
      expect(askButton(tester).count, 1);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(askButton(tester).count, 0);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(askButton(tester).count, 0);
      expect(isSelected(tester, 1), isFalse);
    });

    testWidgets('coming back highlights the sent lines for about 2 seconds', (
      tester,
    ) async {
      await pumpReader(tester);
      await doubleTap(tester, 2);
      await doubleTap(tester, 3);
      await tester.tap(find.byType(AskAiButton));
      await tester.pumpAndSettle();

      final highlight = Theme.of(
        tester.element(find.byType(ReaderScreen)),
      ).colorScheme.primaryContainer;
      Color? color(int n) => decoration(tester, n).color;
      expect(color(2), isNot(highlight));

      // Windows: focus flickers back while the browser opens; not a return.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(color(2), isNot(highlight));
      await tester.pump(const Duration(seconds: 30)); // she reads ChatGPT

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(color(2), highlight);
      expect(color(3), highlight);
      expect(color(1), isNot(highlight));
      expect(uiBox.get('ask_pending'), isNull, reason: 'shown once');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(color(2), isNot(highlight));
    });

    testWidgets(
      'DeepSeek + clipboard failure: dialog with the prompt to copy',
      (tester) async {
        await pumpReader(tester, ai: AiTarget.deepSeek);
        clipboardFails = true;
        await doubleTap(tester, 1);
        await tester.tap(find.byType(AskAiButton));
        await tester.pumpAndSettle();

        final prompt = buildPrompt(
          AskMode.explain.defaultTemplate,
          course,
          digoxin,
          [line(1)],
        );
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          prompt,
        );
        expect(opened, isEmpty);

        clipboardFails = false;
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(clipboard, prompt);
        expect(opened, [Uri.parse(deepSeekUrl)]);
      },
    );

    testWidgets('ChatGPT pre-fill: a clipboard failure is ignored', (
      tester,
    ) async {
      await pumpReader(tester);
      clipboardFails = true;
      await doubleTap(tester, 1);
      await tester.tap(find.byType(AskAiButton));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      expect(opened.single.queryParameters['q'], isNotEmpty);
    });
  });

  group('saved templates', () {
    late Box uiBox;
    setUp(() async => uiBox = await Hive.openBox('ui', bytes: Uint8List(0)));
    tearDown(() => uiBox.close());

    Map<AskMode, String> templates() {
      final container = ProviderContainer(
        overrides: [uiBoxProvider.overrideWithValue(uiBox)],
      );
      addTearDown(container.dispose);
      return container.read(promptTemplatesProvider);
    }

    test('a saved copy of an earlier default is replaced by the new one', () {
      for (final old in AskMode.explain.previousDefaults) {
        uiBox.put('prompt_explain', old);
        expect(templates()[AskMode.explain], AskMode.explain.defaultTemplate);
        expect(uiBox.get('prompt_explain'), isNull);
      }
    });

    test('a template she really edited is kept', () {
      uiBox.put('prompt_explain', 'My own words: {text}');
      expect(templates()[AskMode.explain], 'My own words: {text}');
    });

    test('saving the default unchanged stores nothing', () {
      final container = ProviderContainer(
        overrides: [uiBoxProvider.overrideWithValue(uiBox)],
      );
      addTearDown(container.dispose);
      container
          .read(promptTemplatesProvider.notifier)
          .set(AskMode.explain, AskMode.explain.defaultTemplate);
      expect(uiBox.get('prompt_explain'), isNull);
      expect(
        container.read(promptTemplatesProvider)[AskMode.explain],
        AskMode.explain.defaultTemplate,
      );
    });
  });

  group('AI targets', () {
    test(
      'ChatGPT link encodes the prompt (spaces as %20, quotes, Amharic)',
      () {
        const prompt = 'Explain "Na⁺/K⁺" in ቀላል Amharic & English';
        final uri = AiTarget.chatGpt.uriFor(prompt);
        expect(uri.toString(), startsWith('https://chatgpt.com/?q='));
        expect(uri.toString(), contains('Explain%20%22Na'));
        expect(uri.toString(), isNot(contains('+')));
        expect(uri.queryParameters['q'], prompt);
        expect(AiTarget.chatGpt.prefills(prompt), isTrue);
      },
    );

    test('very long prompts fall back to the plain ChatGPT link', () {
      final prompt = 'x' * AiTarget.maxPrefillUrlLength;
      expect(AiTarget.chatGpt.uriFor(prompt), Uri.parse(chatGptUrl));
      expect(AiTarget.chatGpt.prefills(prompt), isFalse);
    });

    test('DeepSeek never pre-fills', () {
      expect(AiTarget.deepSeek.uriFor('hello'), Uri.parse(deepSeekUrl));
      expect(AiTarget.deepSeek.prefills('hello'), isFalse);
    });
  });
}
