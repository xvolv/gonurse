import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Temporary stand-in for the Note reader (step 4).
class NotePlaceholderScreen extends ConsumerWidget {
  const NotePlaceholderScreen(
      {super.key, required this.courseId, required this.noteId});

  final String courseId;
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider(courseId));
    final note = course?.notesById[noteId];
    return Scaffold(
      appBar: AppBar(),
      body: note == null
          ? const Center(child: Text('Note not found'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text([course!.course, ...note.path].join(' › '),
                      style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Text('Note: ${note.title}',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
    );
  }
}
