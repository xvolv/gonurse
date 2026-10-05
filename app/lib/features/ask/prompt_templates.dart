import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/providers.dart';

/// The three Ask AI modes and their default prompt templates.
///
/// `{topic}` is replaced by the note title and breadcrumb, `{text}` by the
/// selected lines (see [joinLines]). Settings can override each template
/// (stored in Hive).
enum AskMode {
  explain(
    'Explain in Amharic',
    '''
በአማርኛ ብቻ መልስ። (Reply ONLY in Amharic, in Ge'ez script. Not English, not Tigrinya, not any other language.)

I am a nursing student preparing for the Ethiopian national nursing exit exam. Explain the lines below in simple Amharic, like a senior nurse teaching a junior.
Rules:
- Write the whole answer in Amharic.
- Keep medical terms and drug names in English inside brackets, e.g. ደም ግፊት (hypertension).
- Explain each line by its number.
- End with one short clinical example of how the exam could ask it.

Text:
{text}

አስታውስ፦ መልሱ በሙሉ በአማርኛ ይሁን። (Reminder: the entire answer must be in Amharic.)''',
    [
      // Earlier defaults: a saved copy equal to one of these was never edited.
      '''
I am a nursing student in Ethiopia preparing for the national exit exam.
Explain the text below in simple Amharic.
Keep medical terms in English.
Use a real-life example from a hospital or daily life.
Then give me one exam-style question about it with the answer.

Topic: {topic}
Text: "{text}"''',
      '''
I am a nursing student in Ethiopia preparing for the national exit exam.
Explain the text below in simple Amharic.
Keep medical terms in English.
Use a real-life example from a hospital or daily life.
Then give me one exam-style question about it with the answer.

Topic: {topic}
Text:
"{text}"''',
    ],
  ),

  simpler('Simpler', '''
I am a nursing student in Ethiopia. I don't understand the text below at all.
Explain it like I know nothing, in simple Amharic, using a short story or an everyday analogy.
Keep medical terms in English. Keep it short.

Topic: {topic}
Text:
"{text}"'''),

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
Text:
"{text}"''');

  const AskMode(
    this.label,
    this.defaultTemplate, [
    this.previousDefaults = const [],
  ]);

  final String label;
  final String defaultTemplate;

  /// Older versions of [defaultTemplate].
  final List<String> previousDefaults;
}

/// Longest combined text of the selected lines put into a prompt.
const maxPromptTextLength = 1500;

/// The selected lines as the prompt's `{text}`: one line stays as it is;
/// several are numbered "1. …", "2. …", one per row. Lines that would go past
/// [maxPromptTextLength] are left out (cut at a line boundary) and "…" added.
String joinLines(List<String> lines) {
  final numbered = lines.length == 1
      ? lines
      : [for (final (i, l) in lines.indexed) '${i + 1}. $l'];
  final kept = <String>[];
  var length = 0;
  for (final line in numbered) {
    final added = (kept.isEmpty ? 0 : 1) + line.characters.length;
    if (length + added > maxPromptTextLength) {
      // A single line longer than the cap is cut inside the line.
      if (kept.isEmpty) {
        kept.add(line.characters.take(maxPromptTextLength).toString());
      }
      return '${kept.join('\n')}\n…';
    }
    kept.add(line);
    length += added;
  }
  return kept.join('\n');
}

String fillTemplate(
  String template, {
  required String topic,
  required String text,
}) => template.replaceAll('{topic}', topic).replaceAll('{text}', text);

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
    return {for (final m in AskMode.values) m: _saved(box, m)};
  }

  /// Her edited template, or the default. A saved copy of an earlier default
  /// was never really edited, so it is dropped and the new default used.
  String _saved(Box box, AskMode mode) {
    final saved = box.get(_key(mode)) as String?;
    if (saved == null || mode.previousDefaults.contains(saved)) {
      if (saved != null) box.delete(_key(mode));
      return mode.defaultTemplate;
    }
    return saved;
  }

  void set(AskMode mode, String template) {
    // Saving the default unchanged is not an edit: keep following updates.
    if (template == mode.defaultTemplate) return reset(mode);
    ref.read(uiBoxProvider).put(_key(mode), template);
    state = {...state, mode: template};
  }

  void reset(AskMode mode) {
    ref.read(uiBoxProvider).delete(_key(mode));
    state = {...state, mode: mode.defaultTemplate};
  }
}
