import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/providers.dart';
import '../../models/course.dart';
import '../ask/ask_action.dart';
import '../ask/prompt_templates.dart';
import 'note_page.dart';

/// Where she was reading, saved so the app reopens there.
class LastPosition {
  static const _key = 'last_note';

  final String courseId;
  final String noteId;
  final double offset;

  const LastPosition(this.courseId, this.noteId, this.offset);

  static LastPosition? read(Box box) {
    final m = box.get(_key) as Map?;
    if (m == null) return null;
    return LastPosition(
      m['course'] as String,
      m['note'] as String,
      (m['offset'] as num).toDouble(),
    );
  }

  void save(Box box) =>
      box.put(_key, {'course': courseId, 'note': noteId, 'offset': offset});
}

/// Notes one per page. Swiping moves through the whole course in order, so
/// the end of a topic continues into the next topic.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.courseId,
    required this.noteId,
    this.initialOffset = 0,
  });

  final String courseId;
  final String noteId;
  final double initialOffset;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _pages;
  late int _index;

  bool _asking = false;
  AskMode _mode = AskMode.explain;

  /// Line she asked about, briefly highlighted when she comes back.
  AskPending? _highlight;
  Timer? _highlightTimer;

  /// Runs for 2 seconds after a badge tap; resumes during it are ignored.
  Timer? _justAsked;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final course = ref.read(courseProvider(widget.courseId));
    final i = course?.allNotes.indexWhere((n) => n.id == widget.noteId) ?? -1;
    _index = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _index);
    _save(widget.noteId, widget.initialOffset);
    _lifecycle = AppLifecycleListener(onResume: _showPendingHighlight);
    // Also covers the app being closed while she was in DeepSeek.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showPendingHighlight(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _highlightTimer?.cancel();
    _justAsked?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _save(String noteId, double offset) => LastPosition(
    widget.courseId,
    noteId,
    offset,
  ).save(ref.read(uiBoxProvider));

  void _showPendingHighlight() {
    // On Windows the app briefly regains focus while the browser opens; that
    // is not her coming back, so keep the highlight for the real return.
    if (_justAsked?.isActive ?? false) return;
    final box = ref.read(uiBoxProvider);
    final pending = AskPending.read(box);
    if (pending == null || !mounted) return;
    AskPending.clear(box);
    setState(() => _highlight = pending);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  void _ask(Course course, Note note, Line line) {
    setState(() => _asking = false);
    _justAsked?.cancel();
    _justAsked = Timer(const Duration(seconds: 2), () {});
    askAboutLine(
      context: context,
      ref: ref,
      course: course,
      note: note,
      line: line,
      mode: _mode,
    );
  }

  PreferredSizeWidget _askBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Tap a number'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _asking = false),
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// The three modes. They wrap onto two rows on narrow phones, so none is
  /// hidden off screen.
  Widget _modeChips() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in AskMode.values)
              ChoiceChip(
                label: Text(m.label, style: const TextStyle(fontSize: 15)),
                showCheckmark: false,
                selected: _mode == m,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider(widget.courseId));
    if (course == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final notes = course.allNotes;
    final current = notes[_index.clamp(0, notes.length - 1)];
    final topic = course.topicByNoteId[current.id]!;
    final position =
        '${topic.notes.indexOf(current) + 1} / ${topic.notes.length}';

    return PopScope(
      // Back leaves Ask mode first.
      canPop: !_asking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _asking = false);
      },
      child: Scaffold(
        appBar: _asking
            ? _askBar()
            : AppBar(
                title: Text(topic.title, overflow: TextOverflow.ellipsis),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Center(
                      child: Text(
                        position,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
        floatingActionButton: _asking
            ? null
            : FloatingActionButton.extended(
                onPressed: () => setState(() => _asking = true),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Ask AI', style: TextStyle(fontSize: 16)),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_asking) _modeChips(),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                // No swiping while choosing a line.
                physics: _asking ? const NeverScrollableScrollPhysics() : null,
                itemCount: notes.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _save(notes[i].id, 0);
                },
                itemBuilder: (context, i) => NotePage(
                  key: ValueKey(notes[i].id),
                  course: course,
                  note: notes[i],
                  initialOffset: notes[i].id == widget.noteId
                      ? widget.initialOffset
                      : 0,
                  onScrolled: (offset) => _save(notes[i].id, offset),
                  onOpenNote: (id) {
                    final target = notes.indexWhere((n) => n.id == id);
                    if (target >= 0) _pages.jumpToPage(target);
                  },
                  askActive: _asking && i == _index,
                  onAsk: (line) => _ask(course, notes[i], line),
                  highlightedLine: _highlight?.noteId == notes[i].id
                      ? _highlight!.lineN
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
