import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('GoNurse')),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not open your notes.\n$e',
                textAlign: TextAlign.center),
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
    final ready = course != null;
    return Card(
      elevation: ready ? 1 : 0,
      color: ready ? null : theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        enabled: ready,
        title: Text(entry.config.title, style: theme.textTheme.titleMedium),
        subtitle: Text(ready
            ? '${course.noteCount} notes · ${course.units.length} units'
            : 'Notes coming soon'),
        trailing: ready ? const Icon(Icons.chevron_right) : null,
        onTap: () {
          // The map screen is built in the next step.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Map for ${entry.config.title} comes next')),
          );
        },
      ),
    );
  }
}
