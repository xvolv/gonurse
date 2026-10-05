import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/content_repository.dart';
import 'package:gonurse/data/providers.dart';
import 'package:gonurse/data/settings.dart';
import 'package:gonurse/features/ask/ai_target.dart';
import 'package:gonurse/features/ask/prompt_templates.dart';
import 'package:gonurse/main.dart';
import 'package:gonurse/models/course.dart';
import 'package:hive/hive.dart';

/// Serves the real Pharmacology notes; [sync] behaves as told.
class FakeRepository implements ContentRepository {
  FakeRepository(this.course);

  final Course course;
  Object syncOutcome = const SocketException('offline');

  @override
  Future<Course?> load(CourseConfig c) async =>
      c.id == 'pharmacology' ? course : null;

  @override
  int localVersion(CourseConfig c) => c.id == 'pharmacology' ? 1 : 0;

  @override
  Future<List<CourseConfig>> sync() async {
    final outcome = syncOutcome;
    if (outcome is List<CourseConfig>) return outcome;
    throw outcome;
  }
}

void main() {
  final course = Course.fromJson(
    jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  late Box uiBox;
  late FakeRepository repo;

  setUp(() async {
    uiBox = await Hive.openBox('ui', bytes: Uint8List(0));
    repo = FakeRepository(course);
  });
  tearDown(() => uiBox.close());

  Future<ProviderContainer> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(repo),
          uiBoxProvider.overrideWithValue(uiBox),
        ],
        child: const GoNurseApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.text('Settings')));
  }

  testWidgets('text size: 3 steps, saved, preview follows', (tester) async {
    final container = await openSettings(tester);
    await tester.tap(find.text('Extra large'));
    await tester.pumpAndSettle();
    expect(container.read(textSizeProvider), 2);
    expect(uiBox.get('text_size'), 2);
    final preview = tester.widget<Text>(
      find.text('The failing heart is a tired pump.'),
    );
    expect(preview.style!.fontSize, 21);
  });

  testWidgets('dark theme switches the whole app and is saved', (tester) async {
    await openSettings(tester);
    Brightness brightness() =>
        Theme.of(tester.element(find.text('Dark theme'))).brightness;
    expect(brightness(), Brightness.light);

    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(uiBox.get('dark_theme'), true);
  });

  testWidgets('AI for explanations: ChatGPT by default, DeepSeek saved', (
    tester,
  ) async {
    final container = await openSettings(tester);
    expect(container.read(aiTargetProvider), AiTarget.chatGpt);
    await tester.tap(find.text('DeepSeek'));
    await tester.pumpAndSettle();
    expect(container.read(aiTargetProvider), AiTarget.deepSeek);
    expect(uiBox.get('ai_target'), 'deepSeek');
  });

  testWidgets('edit a prompt template, then reset it', (tester) async {
    final container = await openSettings(tester);
    await tester.tap(find.text('Prompt: Quiz me'));
    await tester.pumpAndSettle();

    // Without {text} it cannot be saved.
    await tester.enterText(find.byType(TextField), 'Quiz me on {topic}');
    await tester.pump();
    expect(find.text('Keep {text} in the prompt'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'Quiz me: {text}');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(promptTemplatesProvider)[AskMode.quiz],
      'Quiz me: {text}',
    );
    expect(uiBox.get('prompt_quiz'), 'Quiz me: {text}');
    expect(find.text('Edited'), findsOneWidget);

    await tester.tap(find.text('Prompt: Quiz me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(
      container.read(promptTemplatesProvider)[AskMode.quiz],
      AskMode.quiz.defaultTemplate,
    );
    expect(uiBox.get('prompt_quiz'), isNull);
  });

  testWidgets('check for updated notes reports the result', (tester) async {
    await openSettings(tester);
    expect(find.text('Version 1 · 141 notes'), findsOneWidget);

    await tester.tap(find.text('Check for updated notes'));
    await tester.pumpAndSettle();
    expect(
      find.text('No internet. Your saved notes still work.'),
      findsOneWidget,
    );

    repo.syncOutcome = <CourseConfig>[];
    ScaffoldMessenger.of(
      tester.element(find.text('Settings')),
    ).clearSnackBars();
    await tester.tap(find.text('Check for updated notes'));
    await tester.pumpAndSettle();
    expect(find.text('Your notes are up to date.'), findsOneWidget);
  });
}
