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
    required this.onAsk,
    this.initialOffset = 0,
    this.askActive = false,
    this.highlightedLine,
  });

  final Course course;
  final Note note;
  final ValueChanged<String> onOpenNote;
  final ValueChanged<double> onScrolled;
  final double initialOffset;

  /// Ask mode: numbered badges on the lines visible on screen.
  final bool askActive;
  final ValueChanged<Line> onAsk;

  /// Line number `n` to highlight (after returning from DeepSeek).
  final int? highlightedLine;

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
  )..addListener(_scheduleBadges);
  final _stackKey = GlobalKey();
  final _lineKeys = <int, GlobalKey>{};

  /// Visible lines and where their badge goes, in screen order.
  List<(Line, Offset)> _badges = const [];

  @override
  void initState() {
    super.initState();
    if (widget.askActive) _scheduleBadges();
  }

  @override
  void didUpdateWidget(NotePage old) {
    super.didUpdateWidget(old);
    if (widget.askActive != old.askActive) _scheduleBadges();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Badges are placed after layout, so lines can be measured.
  void _scheduleBadges() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _badges = widget.askActive ? _visibleLines() : const []);
    });
  }

  List<(Line, Offset)> _visibleLines() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null) return const [];
    final visible = <(Line, Offset)>[];
    for (final line in widget.note.lines) {
      final box =
          _lineKeys[line.n]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue; // not built: far off screen
      final top = box.localToGlobal(Offset.zero, ancestor: stack);
      // The badge sits on the line's first row, so that row must be on screen.
      if (top.dy >= -4 && top.dy + 36 <= stack.size.height) {
        visible.add((line, top));
      }
    }
    return visible;
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
          child: Stack(
            key: _stackKey,
            children: [
              _content(context, body, colors, note, related),
              if (widget.askActive)
                for (final (i, (line, at)) in _badges.indexed)
                  Positioned(
                    // Centred on the line-number column (30 wide).
                    left: at.dx + 15 - _AskBadge.size / 2,
                    top: at.dy + body * 0.75 - _AskBadge.size / 2,
                    child: _AskBadge(i + 1, onTap: () => widget.onAsk(line)),
                  ),
            ],
          ),
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
          key: _lineKeys.putIfAbsent(line.n, GlobalKey.new),
          line: line,
          highlighted: widget.highlightedLine == line.n,
          lead: kind == SectionKind.lead,
          body: body,
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

/// Large round number shown on a line in Ask mode.
class _AskBadge extends StatelessWidget {
  const _AskBadge(this.number, {required this.onTap});

  static const size = 44.0;

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('ask-badge-$number'),
      color: colors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
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
    super.key,
    required this.line,
    required this.lead,
    required this.body,
    required this.onRefs,
    this.highlighted = false,
  });

  final Line line;
  final bool lead;
  final double body;
  final ValueChanged<List<SourceRef>> onRefs;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refs = parseRefs(line.ref);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer
            : colors.primaryContainer.withAlpha(0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // Only lines from her files can be opened there.
        onLongPress: refs.isEmpty ? null : () => onRefs(refs),
        child: Row(
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
        ),
      ),
    );
  }
}
