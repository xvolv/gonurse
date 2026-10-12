import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../map/map_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_button.dart';

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
    final entry = courses.where((c) => c.id == last.courseId).firstOrNull;
    if (entry?.course.notesById[last.noteId] == null) return;
    Navigator.of(context)
      ..push(
        MaterialPageRoute(
          builder: (_) =>
              MapScreen(courseId: last.courseId, title: entry!.course.course),
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
      appBar: AppBar(
        title: const Text('GoNurse'),
        actions: const [SettingsButton()],
      ),
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
          children: [for (final c in list) _CourseCard(c)],
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(course.course, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${course.noteCount} notes · ${course.units.length} units',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapScreen(courseId: entry.id, title: course.course),
          ),
        ),
      ),
    );
  }
}
