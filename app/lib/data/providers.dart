import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/course.dart';
import 'content_repository.dart';

/// Overridden in `main()` once Hive is open.
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError(),
);

/// A course on the device: its ID (a key of `version.json`) and its notes.
class CourseEntry {
  final String id;
  final Course course;

  const CourseEntry(this.id, this.course);
}

/// All courses, loaded from the device. A version check runs in the
/// background after loading; if it finds new notes the list is reloaded.
final coursesProvider =
    AsyncNotifierProvider<CoursesNotifier, List<CourseEntry>>(
      CoursesNotifier.new,
    );

class CoursesNotifier extends AsyncNotifier<List<CourseEntry>> {
  @override
  Future<List<CourseEntry>> build() async {
    final loaded = await _loadAll();
    Future(checkForUpdates);
    return loaded;
  }

  Future<List<CourseEntry>> _loadAll() async {
    final repo = ref.read(contentRepositoryProvider);
    return [
      for (final id in await repo.courseIds())
        if (await repo.load(id) case final course?) CourseEntry(id, course),
    ];
  }

  /// Fails silently (returns [SyncResult.offline]) when there is no internet.
  Future<SyncResult> checkForUpdates() async {
    await future;
    try {
      final updated = await ref.read(contentRepositoryProvider).sync();
      if (updated.isEmpty) return SyncResult.upToDate;
      state = AsyncData(await _loadAll());
      return SyncResult.updated;
    } catch (_) {
      return SyncResult.offline;
    }
  }
}

/// One course's notes, or null while loading or if it isn't on the device.
final courseProvider = Provider.family<Course?, String>((ref, courseId) {
  for (final entry in ref.watch(coursesProvider).valueOrNull ?? const []) {
    if (entry.id == courseId) return entry.course;
  }
  return null;
});

/// Small UI state that should survive restarts (open map branches, last
/// note, settings). Overridden in `main()` once Hive is open.
final uiBoxProvider = Provider<Box>((ref) => throw UnimplementedError());
