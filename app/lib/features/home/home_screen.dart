import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/course.dart';

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
  const _CourseCard(this.course);

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(course.course, style: theme.textTheme.titleLarge),
        subtitle: Text('${course.noteCount} notes · ${course.units.length} units'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // The map screen is built in the next step.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Map for ${course.course} comes next')),
          );
        },
      ),
    );
  }
}
