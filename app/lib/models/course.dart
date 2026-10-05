/// Data models for a course notes file (e.g. `content/pharmacology_notes.json`).
///
/// The JSON format is fixed; these classes only read it.
library;

class Course {
  final String course;
  final int version;
  final String updated;
  final String language;
  final Map<String, Source> sources;
  final List<Unit> units;

  /// Every note in reading order, and a lookup by note ID.
  final List<Note> allNotes;
  final Map<String, Note> notesById;

  /// The topic each note belongs to, by note ID.
  final Map<String, Topic> topicByNoteId;

  Course({
    required this.course,
    required this.version,
    required this.updated,
    required this.language,
    required this.sources,
    required this.units,
  }) : allNotes = [
         for (final u in units)
           for (final t in u.topics) ...t.notes,
       ],
       notesById = {
         for (final u in units)
           for (final t in u.topics)
             for (final n in t.notes) n.id: n,
       },
       topicByNoteId = {
         for (final u in units)
           for (final t in u.topics)
             for (final n in t.notes) n.id: t,
       };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    course: json['course'] as String,
    version: json['version'] as int,
    updated: json['updated'] as String? ?? '',
    language: json['language'] as String? ?? 'en',
    sources: {
      for (final e in (json['sources'] as Map<String, dynamic>).entries)
        e.key: Source.fromJson(e.value as Map<String, dynamic>),
    },
    units: [
      for (final u in json['units'] as List)
        Unit.fromJson(u as Map<String, dynamic>),
    ],
  );

  int get noteCount => allNotes.length;
}

class Source {
  final String file;
  final int pages;

  /// `page` or `slide`.
  final String kind;

  const Source({required this.file, required this.pages, required this.kind});

  factory Source.fromJson(Map<String, dynamic> json) => Source(
    file: json['file'] as String,
    pages: json['pages'] as int? ?? 0,
    kind: json['kind'] as String? ?? 'page',
  );

  bool get isSlide => kind == 'slide';

  /// Name of the PDF in `files/`. Slide decks are stored as PDFs converted
  /// from PowerPoint, so `x.pptx` becomes `x.pdf` (slide N = PDF page N).
  String get pdfFile => file.toLowerCase().endsWith('.pptx')
      ? '${file.substring(0, file.length - 5)}.pdf'
      : file;
}

class Unit {
  final String id;
  final String title;
  final List<Topic> topics;

  const Unit({required this.id, required this.title, required this.topics});

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
    id: json['id'] as String,
    title: json['title'] as String,
    topics: [
      for (final t in json['topics'] as List)
        Topic.fromJson(t as Map<String, dynamic>),
    ],
  );

  int get noteCount => topics.fold(0, (sum, t) => sum + t.notes.length);
}

class Topic {
  final String title;
  final List<Note> notes;

  const Topic({required this.title, required this.notes});

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    title: json['title'] as String,
    notes: [
      for (final n in json['notes'] as List)
        Note.fromJson(n as Map<String, dynamic>),
    ],
  );
}

class Note {
  final String id;
  final String title;
  final List<String> path;
  final List<Section> sections;
  final List<String> links;
  final List<Flag> flags;

  const Note({
    required this.id,
    required this.title,
    required this.path,
    required this.sections,
    required this.links,
    required this.flags,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    path: [for (final p in json['path'] as List? ?? const []) p as String],
    sections: [
      for (final s in json['sections'] as List)
        Section.fromJson(s as Map<String, dynamic>),
    ],
    links: [for (final l in json['links'] as List? ?? const []) l as String],
    flags: [
      for (final f in json['flags'] as List? ?? const [])
        Flag.fromJson(f as Map<String, dynamic>),
    ],
  );

  List<Line> get lines => [for (final s in sections) ...s.lines];
}

class Section {
  /// Original format: `big_idea`, `how`, `patient`, `facts`, `trap`.
  /// Bedside format: `scene`, `notice`, `actions`, `why`, `traps`, `numbers`.
  /// Other values are allowed and shown plainly.
  final String type;
  final String title;
  final List<Line> lines;

  const Section({required this.type, required this.title, required this.lines});

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    type: json['type'] as String,
    title: json['title'] as String? ?? '',
    lines: [
      for (final l in json['lines'] as List)
        Line.fromJson(l as Map<String, dynamic>),
    ],
  );
}

class Line {
  final int n;
  final String text;
  final String ref;

  /// `notes` (from her files, has a [ref]) or `practice` (standard nursing
  /// practice, [ref] may be empty).
  final String basis;

  const Line({
    required this.n,
    required this.text,
    required this.ref,
    this.basis = 'notes',
  });

  factory Line.fromJson(Map<String, dynamic> json) => Line(
    n: json['n'] as int,
    text: json['text'] as String,
    ref: json['ref'] as String? ?? '',
    basis: json['basis'] as String? ?? 'notes',
  );

  bool get isPractice => basis == 'practice';
}

class Flag {
  /// `conflict` or `outside`.
  final String kind;
  final String text;

  const Flag({required this.kind, required this.text});

  factory Flag.fromJson(Map<String, dynamic> json) =>
      Flag(kind: json['kind'] as String, text: json['text'] as String? ?? '');
}
