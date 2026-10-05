import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/providers.dart';
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
        m['course'] as String, m['note'] as String, (m['offset'] as num).toDouble());
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

  @override
  void initState() {
    super.initState();
    final course = ref.read(courseProvider(widget.courseId));
    final i = course?.allNotes.indexWhere((n) => n.id == widget.noteId) ?? -1;
    _index = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _index);
    _save(widget.noteId, widget.initialOffset);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _save(String noteId, double offset) => LastPosition(widget.courseId, noteId, offset)
      .save(ref.read(uiBoxProvider));

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseProvider(widget.courseId));
    if (course == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final notes = course.allNotes;
    final current = notes[_index.clamp(0, notes.length - 1)];
    final topic = course.topicByNoteId[current.id]!;
    final position = '${topic.notes.indexOf(current) + 1} / ${topic.notes.length}';

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(position, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO(step 5): Ask mode.
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ask AI comes in step 5')));
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Ask AI', style: TextStyle(fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: notes.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          _save(notes[i].id, 0);
        },
        itemBuilder: (context, i) => NotePage(
          key: ValueKey(notes[i].id),
          course: course,
          note: notes[i],
          initialOffset: notes[i].id == widget.noteId ? widget.initialOffset : 0,
          onScrolled: (offset) => _save(notes[i].id, offset),
          onOpenNote: (id) {
            final target = notes.indexWhere((n) => n.id == id);
            if (target >= 0) _pages.jumpToPage(target);
          },
        ),
      ),
    );
  }
}
