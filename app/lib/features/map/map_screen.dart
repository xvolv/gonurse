import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/course.dart';
import '../reader/reader_screen.dart';

/// The course as an expandable tree: Unit → Topic → Note, with search.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.courseId, required this.title});

  final String courseId;
  final String title;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _search = TextEditingController();

  /// Keys of open branches: `u:<unitId>` and `t:<unitId>/<topicTitle>`.
  late final Set<String> _open;

  String get _openKey => 'map_open_${widget.courseId}';

  @override
  void initState() {
    super.initState();
    final saved = ref.read(uiBoxProvider).get(_openKey) as List?;
    _open = {...?saved?.cast<String>()};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    setState(() => _open.contains(key) ? _open.remove(key) : _open.add(key));
    ref.read(uiBoxProvider).put(_openKey, _open.toList());
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReaderScreen(courseId: widget.courseId, noteId: note.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider(widget.courseId));
    final query = _search.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: course == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _SearchField(
                        controller: _search,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: query.length >= 2
                          ? _SearchResults(
                              course: course,
                              query: query,
                              shownQuery: _search.text.trim(),
                              onTap: _openNote,
                            )
                          : _tree(course),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tree(Course course) {
    final rows = <Widget>[];
    for (final unit in course.units) {
      final unitKey = 'u:${unit.id}';
      final unitOpen = _open.contains(unitKey);
      rows.add(
        _TreeRow(
          depth: 0,
          leading: _Chevron(open: unitOpen),
          title: unit.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          count: unit.noteCount,
          onTap: () => _toggle(unitKey),
        ),
      );
      if (!unitOpen) continue;
      for (final topic in unit.topics) {
        final topicKey = 't:${unit.id}/${topic.title}';
        final topicOpen = _open.contains(topicKey);
        rows.add(
          _TreeRow(
            depth: 1,
            leading: _Chevron(open: topicOpen),
            title: topic.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            count: topic.notes.length,
            onTap: () => _toggle(topicKey),
          ),
        );
        if (!topicOpen) continue;
        for (final note in topic.notes) {
          rows.add(
            _TreeRow(
              depth: 2,
              leading: const _Dot(),
              title: note.title,
              style: const TextStyle(fontSize: 16),
              onTap: () => _openNote(note),
            ),
          );
        }
      }
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 16),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search notes',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.course,
    required this.query,
    required this.shownQuery,
    required this.onTap,
  });

  final Course course;

  /// Lower-cased query used for matching; [shownQuery] is what she typed.
  final String query;
  final String shownQuery;
  final ValueChanged<Note> onTap;

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final n in course.allNotes)
        if (n.title.toLowerCase().contains(query)) n,
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No notes match "$shownQuery"',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: muted),
        ),
      );
    }
    return ListView(
      children: [
        for (final note in matches)
          ListTile(
            minTileHeight: 56,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(note.title, style: const TextStyle(fontSize: 16)),
            subtitle: Text(
              note.path.join(' › '),
              style: TextStyle(fontSize: 13, color: muted),
            ),
            onTap: () => onTap(note),
          ),
      ],
    );
  }
}

/// Indent per tree level, and where the chevron/dot column starts.
const _indent = 28.0;
const _leftPad = 8.0;
const _leadingWidth = 24.0;

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.leading,
    required this.title,
    required this.style,
    required this.onTap,
    this.count,
  });

  final int depth;
  final Widget leading;
  final String title;
  final TextStyle style;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: _GuidePainter(depth, colors.outlineVariant),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: EdgeInsets.only(
              left: _leftPad + depth * _indent,
              right: 20,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _leadingWidth,
                  child: Center(child: leading),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(title, style: style),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin vertical lines under each parent's chevron, showing the nesting.
class _GuidePainter extends CustomPainter {
  _GuidePainter(this.depth, this.color);

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < depth; i++) {
      final x = _leftPad + i * _indent + _leadingWidth / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.depth != depth || old.color != color;
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => Icon(
    open ? Icons.expand_more : Icons.chevron_right,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
  );
}
