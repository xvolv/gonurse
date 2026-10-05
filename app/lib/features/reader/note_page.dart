import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ref_parser.dart';
import '../../data/settings.dart';
import '../../models/course.dart';
import '../pdf/open_source.dart';
import 'section_style.dart';

/// One note: breadcrumb, title, sections with numbered lines, flags and
/// related notes.
class NotePage extends ConsumerStatefulWidget {
  const NotePage({
    super.key,
    required this.course,
    required this.note,
    required this.onOpenNote,
    required this.onScrolled,
    required this.onToggleLine,
    this.initialOffset = 0,
    this.selectedLines = const {},
    this.highlightedLines = const {},
  });

  final Course course;
  final Note note;
  final ValueChanged<String> onOpenNote;
  final ValueChanged<double> onScrolled;
  final double initialOffset;

  /// Double-tap on a line selects or unselects it (by line number `n`).
  final ValueChanged<int> onToggleLine;
  final Set<int> selectedLines;

  /// Lines briefly highlighted after she comes back from the AI.
  final Set<int> highlightedLines;

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ref.watch(bodyFontSizeProvider);
    final colors = Theme.of(context).colorScheme;
    final note = widget.note;
    final related = [
      for (final id in note.links)
        if (widget.course.notesById[id] != null) widget.course.notesById[id]!,
    ];

    return NotificationListener<ScrollEndNotification>(
      onNotification: (n) {
        widget.onScrolled(_scroll.offset);
        return false;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _content(context, body, colors, note, related),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    double body,
    ColorScheme colors,
    Note note,
    List<Note> related,
  ) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Text(
          [widget.course.course, ...note.path].join(' › '),
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          note.title,
          style: TextStyle(
            fontSize: body * 1.45,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        // Refs, practice tags and flags stay in the data but are not shown:
        // the page is only text. Long-press a line to open it in her notes.
        for (final section in note.sections) _section(section, body),
        if (related.isNotEmpty) ...[
          const _Label('Related'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final r in related)
                ActionChip(
                  label: Text(r.title, style: const TextStyle(fontSize: 15)),
                  onPressed: () => widget.onOpenNote(r.id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _section(Section section, double body) {
    final kind = sectionKind(section.type);
    final worked = kind == SectionKind.worked;
    final children = [
      _SectionLabel(section, top: worked ? 16 : 28),
      for (final line in section.lines)
        _LineRow(
          line: line,
          selected: widget.selectedLines.contains(line.n),
          highlighted: widget.highlightedLines.contains(line.n),
          lead: kind == SectionKind.lead,
          body: body,
          onDoubleTap: () => widget.onToggleLine(line.n),
          onRefs: (refs) => openRefs(context, widget.course, refs),
        ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    if (!worked) return column;
    // The practice question stands apart in a lightly tinted box.
    return Container(
      // A note can have several practice questions: one key per box.
      key: ValueKey('worked-box-${section.lines.firstOrNull?.n}'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(110),
        borderRadius: BorderRadius.circular(14),
      ),
      child: column,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.color, this.top = 28});

  final String text;
  final Color? color;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.section, {this.top = 28});

  final Section section;
  final double top;

  @override
  Widget build(BuildContext context) => _Label(
    sectionTitle(section),
    top: top,
    color: sectionKind(section.type) == SectionKind.danger
        ? Theme.of(context).colorScheme.error
        : null,
  );
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.lead,
    required this.body,
    required this.onDoubleTap,
    required this.onRefs,
    this.selected = false,
    this.highlighted = false,
  });

  final Line line;
  final bool lead;
  final double body;
  final VoidCallback onDoubleTap;
  final ValueChanged<List<SourceRef>> onRefs;

  /// Chosen for Ask AI: tinted, with an accent bar on the left.
  final bool selected;

  /// Just sent to the AI: briefly tinted when she comes back.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refs = parseRefs(line.ref);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          key: ValueKey('line-${line.n}'),
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withAlpha(170)
                : highlighted
                ? colors.primaryContainer
                : colors.primaryContainer.withAlpha(0),
            border: Border(
              left: BorderSide(
                width: 4,
                color: selected ? colors.primary : colors.primary.withAlpha(0),
              ),
            ),
          ),
          child: InkWell(
            // Single tap does nothing, so reading and scrolling stay calm.
            onDoubleTap: onDoubleTap,
            // Only lines from her files can be opened there.
            onLongPress: refs.isEmpty ? null : () => onRefs(refs),
            child: _content(colors),
          ),
        ),
      ),
    );
  }

  Widget _content(ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Padding(
            padding: EdgeInsets.only(top: body * 0.2),
            child: Text(
              '${line.n}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: body * 0.8,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.text,
                style: TextStyle(
                  fontSize: lead ? body * 1.15 : body,
                  fontStyle: lead ? FontStyle.italic : null,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
