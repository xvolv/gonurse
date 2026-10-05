import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../config.dart';
import '../models/course.dart';
import 'content_repository.dart';

/// Overridden in `main()` once Hive is open.
final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => throw UnimplementedError(),
);

/// A course from [courses], with its notes if they are on the device yet.
class CourseEntry {
  final CourseConfig config;
  final Course? course;

  const CourseEntry(this.config, this.course);
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
    return [for (final c in courses) CourseEntry(c, await repo.load(c))];
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

/// One course's notes, or null while loading or if it has none yet.
final courseProvider = Provider.family<Course?, String>((ref, courseId) {
  for (final entry in ref.watch(coursesProvider).valueOrNull ?? const []) {
    if (entry.config.id == courseId) return entry.course;
  }
  return null;
});

/// Small UI state that should survive restarts (open map branches, last
/// note, settings). Overridden in `main()` once Hive is open.
final uiBoxProvider = Provider<Box>((ref) => throw UnimplementedError());
