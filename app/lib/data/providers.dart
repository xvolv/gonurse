import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/course.dart';
import 'content_repository.dart';

/// Overridden in `main()` once Hive is open.
final contentRepositoryProvider =
    Provider<ContentRepository>((ref) => throw UnimplementedError());

/// All courses, loaded from the device. A version check runs in the
/// background after loading; if it finds new notes the list is reloaded.
final coursesProvider =
    AsyncNotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class CoursesNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final loaded = await _loadAll();
    Future(checkForUpdates);
    return loaded;
  }

  Future<List<Course>> _loadAll() async {
    final repo = ref.read(contentRepositoryProvider);
    return [for (final c in courses) await repo.load(c)];
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
