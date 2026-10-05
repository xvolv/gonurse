import '../../models/course.dart';

/// How a section is shown. Unknown (future) section types are [plain].
enum SectionKind {
  /// The first thing she reads (`big_idea`, `scene`): larger and italic.
  lead,
  plain,

  /// Exam traps (`trap`, `traps`): red.
  danger,

  /// Practice question with answers (`worked`): in a tinted box.
  worked,
}

SectionKind sectionKind(String type) => switch (type) {
  'big_idea' || 'scene' => SectionKind.lead,
  'trap' || 'traps' => SectionKind.danger,
  'worked' => SectionKind.worked,
  _ => SectionKind.plain, // includes `rules`, `notice`, `actions`, ...
};

/// Used only when a section has no title in the JSON.
const _defaultTitles = {
  'big_idea': 'The big idea',
  'how': 'How it works',
  'patient': 'For the patient',
  'facts': 'Remember',
  'trap': 'Exam trap',
  'scene': "The patient you'll meet",
  'rules': 'The decision rules',
  'notice': 'What you notice → what it means',
  'actions': 'What the nurse does',
  'why': 'Why',
  'traps': 'How the exam tricks you',
  'numbers': 'Key numbers',
  'worked': 'Practice question',
};

String sectionTitle(Section s) =>
    s.title.isNotEmpty ? s.title : _defaultTitles[s.type] ?? s.type;
