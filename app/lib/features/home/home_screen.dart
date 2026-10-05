import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../map/map_screen.dart';
import '../reader/reader_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(coursesProvider, (_, courses) {
      if (_resumed || !courses.hasValue) return;
      _resumed = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _resume(courses.value!),
      );
    }, fireImmediately: true);
  }

  /// Reopens the note she was last reading, with the map behind it.
  void _resume(List<CourseEntry> courses) {
    final last = LastPosition.read(ref.read(uiBoxProvider));
    if (last == null || !mounted) return;
    final entry = courses
        .where((c) => c.config.id == last.courseId)
        .firstOrNull;
    if (entry?.course?.notesById[last.noteId] == null) return;
    Navigator.of(context)
      ..push(
        MaterialPageRoute(
          builder: (_) =>
              MapScreen(courseId: last.courseId, title: entry!.config.title),
        ),
      )
      ..push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            courseId: last.courseId,
            noteId: last.noteId,
            initialOffset: last.offset,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GoNurse')),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not open your notes.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          // Courses with notes first; the rest keep the exam order.
          children: [
            for (final c in list)
              if (c.course != null) _CourseCard(c),
            for (final c in list)
              if (c.course == null) _CourseCard(c),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard(this.entry);

  final CourseEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = entry.course;
    final ready = course != null;
    return Card(
      elevation: ready ? 1 : 0,
      color: ready ? null : theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        enabled: ready,
        title: Text(entry.config.title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          ready
              ? '${course.noteCount} notes · ${course.units.length} units'
              : 'Notes coming soon',
        ),
        trailing: ready ? const Icon(Icons.chevron_right) : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MapScreen(courseId: entry.config.id, title: entry.config.title),
          ),
        ),
      ),
    );
  }
}
