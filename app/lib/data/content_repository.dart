import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/course.dart';

enum SyncResult { updated, upToDate, offline }

/// Loads course notes from local storage and keeps them up to date.
///
/// The courses are the keys of `version.json`: the bundled copy (an app
/// asset) lists the courses that work offline from the first launch, and the
/// one at [contentBaseUrl] can add new ones. Each course's notes are in
/// `<course>_notes.json`. A newer version downloaded from the server is saved
/// in Hive and used instead of the bundled one; whichever has the higher
/// version wins, so an app update with newer bundled notes also takes effect.
class ContentRepository {
  ContentRepository(
    this._box, {
    required Future<String> Function(String asset) loadAsset,
    http.Client? client,
  }) : _loadAsset = loadAsset,
       _client = client ?? http.Client();

  static const boxName = 'content';

  /// Courses that only came from the server, in the order they arrived.
  static const _downloadedIdsKey = 'course_ids';

  final Box _box;
  final Future<String> Function(String asset) _loadAsset;
  final http.Client _client;
  final _bundledVersions = <String, int>{};
  Future<List<String>>? _bundledIds;

  String _jsonKey(String id) => '$id.json';
  String _versionKey(String id) => '$id.version';

  int _storedVersion(String id) => _box.get(_versionKey(id)) as int? ?? 0;

  Future<List<String>> _bundled() => _bundledIds ??= _loadAsset(
    '${bundledContentDir}version.json',
  ).then((json) => (jsonDecode(json) as Map<String, dynamic>).keys.toList());

  List<String> get _downloadedIds => [
    for (final id in _box.get(_downloadedIdsKey) as List? ?? const [])
      id as String,
  ];

  /// All courses on the device: bundled ones first, in `version.json` order,
  /// then any that were downloaded later.
  Future<List<String>> courseIds() async {
    final bundled = await _bundled();
    return [
      ...bundled,
      for (final id in _downloadedIds)
        if (!bundled.contains(id)) id,
    ];
  }

  /// Version of the copy [load] returns.
  int localVersion(String id) {
    final stored = _storedVersion(id);
    final bundled = _bundledVersions[id] ?? 0;
    return stored > bundled ? stored : bundled;
  }

  /// Loads a course from the device, or null if it isn't here yet.
  /// Never touches the network.
  Future<Course?> load(String id) async {
    final bundled = (await _bundled()).contains(id)
        ? await _loadAsset('$bundledContentDir${notesFile(id)}')
        : null;
    _bundledVersions[id] = bundled == null ? 0 : _peekVersion(bundled);
    final stored = _box.get(_jsonKey(id)) as String?;
    final useStored =
        stored != null && _storedVersion(id) > _bundledVersions[id]!;
    final json = useStored ? stored : bundled;
    return json == null ? null : compute(_parseCourse, json);
  }

  /// Downloads every course whose version in the server's `version.json` is
  /// newer than the local one, including courses the app has never seen.
  /// Throws on network errors; the local copies are left as they are.
  Future<List<String>> sync() async {
    final remote =
        jsonDecode(await _get('version.json')) as Map<String, dynamic>;
    final known = await courseIds();
    final updated = <String>[];
    for (final MapEntry(key: id, value: remoteVersion) in remote.entries) {
      if (remoteVersion is! int) continue;
      if (!_bundledVersions.containsKey(id)) await load(id);
      if (remoteVersion <= localVersion(id)) continue;
      final json = await _get(notesFile(id));
      await compute(_parseCourse, json); // don't store a file we can't read
      await _box.put(_jsonKey(id), json);
      await _box.put(_versionKey(id), remoteVersion);
      if (!known.contains(id)) {
        await _box.put(_downloadedIdsKey, [..._downloadedIds, id]);
      }
      updated.add(id);
    }
    return updated;
  }

  Future<String> _get(String file) async {
    final res = await _client
        .get(Uri.parse('$contentBaseUrl$file'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode} for $file');
    }
    return utf8.decode(res.bodyBytes);
  }

  /// Reads `"version": N` from the start of a notes file without parsing it all.
  static int _peekVersion(String json) {
    final m = RegExp(
      r'"version"\s*:\s*(\d+)',
    ).firstMatch(json.substring(0, json.length.clamp(0, 2000)));
    return m == null ? 0 : int.parse(m.group(1)!);
  }
}

Course _parseCourse(String json) =>
    Course.fromJson(jsonDecode(json) as Map<String, dynamic>);
