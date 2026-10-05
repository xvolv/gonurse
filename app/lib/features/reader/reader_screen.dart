import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/providers.dart';
import '../../models/course.dart';
import '../ask/ai_target.dart';
import '../ask/ask_action.dart';
import '../ask/ask_button.dart';
import '../ask/prompt_templates.dart';
import '../settings/settings_button.dart';
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

  /// Lines selected (double-tap) in the current note, by line number.
  /// Swiping to another note clears them.
  final _selected = <int>{};

  /// Lines she sent to the AI, briefly highlighted when she comes back.
  AskPending? _highlight;
  Timer? _highlightTimer;

  /// Runs for 2 seconds after sending; resumes during it are ignored.
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
    // Also covers the app being closed while she was in the AI app.
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

  void _toggle(int n) => setState(
    () => _selected.contains(n) ? _selected.remove(n) : _selected.add(n),
  );

  /// Sends the selected lines (in note order) to the AI with [mode].
  void _send(Note note, AskMode mode) {
    final lines = [
      for (final l in note.lines)
        if (_selected.contains(l.n)) l,
    ];
    if (lines.isEmpty) return;
    setState(_selected.clear);
    _justAsked?.cancel();
    _justAsked = Timer(const Duration(seconds: 2), () {});
    askAboutLines(
      context: context,
      ref: ref,
      course: ref.read(courseProvider(widget.courseId))!,
      note: note,
      lines: lines,
      mode: mode,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              key: const ValueKey('clear-selection'),
              icon: const Icon(Icons.close),
              onPressed: () => setState(_selected.clear),
            ),
          AskAiButton(
            count: _selected.length,
            label: ref.watch(aiTargetProvider).label,
            onSend: (mode) => _send(current, mode),
          ),
          const SettingsButton(),
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 4),
            child: Center(
              child: Text(
                position,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: notes.length,
        onPageChanged: (i) {
          // The selection belongs to one note.
          setState(() {
            _index = i;
            _selected.clear();
          });
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
          selectedLines: i == _index ? _selected : const {},
          onToggleLine: _toggle,
          highlightedLines: _highlight?.noteId == notes[i].id
              ? _highlight!.lines
              : const {},
        ),
      ),
    );
  }
}
