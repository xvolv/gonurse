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
I am preparing for the Ethiopian national nursing exit exam. The exam has ONLY
clinical scenario questions, for example:
"A 28-year-old multiparous woman visited a hospital for contraception service.
She was on her 14 days of postpartum period and not breastfeeding. She had no
history of chronic disease. What is the most appropriate contraceptive method
for the client?"

Using the text below, write 3 questions in exactly that style:
- Start with a patient or situation: age, condition, key findings or vital signs.
- Ask "most appropriate", "priority", "first action" or "most likely".
- 4 options (a–d) that all look reasonable; only one is best.
- Ask one question at a time and wait for my answer.
- After I answer, say if I'm right, then explain in simple Amharic (medical terms
  in English) why the correct option is right AND why each wrong option is wrong.
- If I say "I don't know" or answer wrong, immediately give the correct answer
  and explain it. Never leave a question unanswered.

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
