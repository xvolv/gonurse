import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// The three Ask AI modes and their default prompt templates.
///
/// `{topic}` is replaced by the note title and breadcrumb, `{text}` by the
/// tapped line. Settings can override each template (stored in Hive).
enum AskMode {
  explain('Explain in Amharic', '''
I am a nursing student in Ethiopia preparing for the national exit exam.
Explain the text below in simple Amharic.
Keep medical terms in English.
Use a real-life example from a hospital or daily life.
Then give me one exam-style question about it with the answer.

Topic: {topic}
Text: "{text}"'''),

  simpler('Simpler', '''
I am a nursing student in Ethiopia. I don't understand the text below at all.
Explain it like I know nothing, in simple Amharic, using a short story or an everyday analogy.
Keep medical terms in English. Keep it short.

Topic: {topic}
Text: "{text}"'''),

  quiz('Quiz me', '''
I am a nursing student in Ethiopia preparing for the national exit exam.
Ask me 3 exam-style multiple-choice questions about the text below, one at a time.
Wait for my answer before showing the correct one and explaining why, in simple Amharic with English medical terms.

Topic: {topic}
Text: "{text}"''');

  const AskMode(this.label, this.defaultTemplate);

  final String label;
  final String defaultTemplate;
}

/// Longest line text put into a prompt.
const maxPromptTextLength = 1000;

String fillTemplate(
  String template, {
  required String topic,
  required String text,
}) {
  final chars = text.characters;
  final capped = chars.length > maxPromptTextLength
      ? chars.take(maxPromptTextLength).toString()
      : text;
  return template.replaceAll('{topic}', topic).replaceAll('{text}', capped);
}

/// Current template for each mode: her edited version, or the default.
final promptTemplatesProvider =
    NotifierProvider<PromptTemplatesNotifier, Map<AskMode, String>>(
      PromptTemplatesNotifier.new,
    );

class PromptTemplatesNotifier extends Notifier<Map<AskMode, String>> {
  String _key(AskMode m) => 'prompt_${m.name}';

  @override
  Map<AskMode, String> build() {
    final box = ref.read(uiBoxProvider);
    return {
      for (final m in AskMode.values)
        m: box.get(_key(m)) as String? ?? m.defaultTemplate,
    };
  }

  void set(AskMode mode, String template) {
    ref.read(uiBoxProvider).put(_key(mode), template);
    state = {...state, mode: template};
  }

  void reset(AskMode mode) {
    ref.read(uiBoxProvider).delete(_key(mode));
    state = {...state, mode: mode.defaultTemplate};
  }
}
