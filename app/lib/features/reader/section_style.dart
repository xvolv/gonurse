import '../../models/course.dart';

/// How a section is shown. Unknown (future) section types are [plain].
enum SectionKind {
  /// The first thing she reads (`big_idea`, `scene`): larger and italic.
  lead,
  plain,

  /// Exam traps (`trap`, `traps`): red.
  danger,
}

SectionKind sectionKind(String type) => switch (type) {
      'big_idea' || 'scene' => SectionKind.lead,
      'trap' || 'traps' => SectionKind.danger,
      _ => SectionKind.plain,
    };

/// Used only when a section has no title in the JSON.
const _defaultTitles = {
  'big_idea': 'The big idea',
  'how': 'How it works',
  'patient': 'For the patient',
  'facts': 'Remember',
  'trap': 'Exam trap',
  'scene': "The patient you'll meet",
  'notice': 'What you notice → what it means',
  'actions': 'What the nurse does',
  'why': 'Why',
  'traps': 'How the exam tricks you',
  'numbers': 'Key numbers',
};

String sectionTitle(Section s) =>
    s.title.isNotEmpty ? s.title : _defaultTitles[s.type] ?? s.type;
