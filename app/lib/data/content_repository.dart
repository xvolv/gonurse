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
/// Each course has a bundled copy (an app asset). A newer version downloaded
/// from [contentBaseUrl] is saved in Hive and used instead. Whichever of the
/// two has the higher version wins, so an app update with newer bundled notes
/// also takes effect.
class ContentRepository {
  ContentRepository(
    this._box, {
    required Future<String> Function(String asset) loadAsset,
    http.Client? client,
  })  : _loadAsset = loadAsset,
        _client = client ?? http.Client();

  static const boxName = 'content';

  final Box _box;
  final Future<String> Function(String asset) _loadAsset;
  final http.Client _client;
  final _bundledVersions = <String, int>{};

  String _jsonKey(String id) => '$id.json';
  String _versionKey(String id) => '$id.version';

  int _storedVersion(String id) => _box.get(_versionKey(id)) as int? ?? 0;

  /// Version of the copy [load] returns.
  int localVersion(CourseConfig c) =>
      _storedVersion(c.id) > (_bundledVersions[c.id] ?? 0)
          ? _storedVersion(c.id)
          : _bundledVersions[c.id] ?? 0;

  /// Loads a course from the device, or null if it has no notes yet.
  /// Never touches the network.
  Future<Course?> load(CourseConfig c) async {
    final bundled = c.asset == null ? null : await _loadAsset(c.asset!);
    _bundledVersions[c.id] = bundled == null ? 0 : _peekVersion(bundled);
    final stored = _box.get(_jsonKey(c.id)) as String?;
    final useStored =
        stored != null && _storedVersion(c.id) > _bundledVersions[c.id]!;
    final json = useStored ? stored : bundled;
    return json == null ? null : compute(_parseCourse, json);
  }

  /// Downloads any course whose version in `version.json` is newer than the
  /// local one. Throws on network errors; the local copies are left as they are.
  Future<List<CourseConfig>> sync() async {
    final remote =
        jsonDecode(await _get('version.json')) as Map<String, dynamic>;
    final updated = <CourseConfig>[];
    for (final c in courses) {
      final remoteVersion = remote[c.id];
      if (remoteVersion is! int || remoteVersion <= localVersion(c)) continue;
      final json = await _get(c.remoteFile);
      await compute(_parseCourse, json); // don't store a file we can't read
      await _box.put(_jsonKey(c.id), json);
      await _box.put(_versionKey(c.id), remoteVersion);
      updated.add(c);
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
    final m = RegExp(r'"version"\s*:\s*(\d+)')
        .firstMatch(json.substring(0, json.length.clamp(0, 2000)));
    return m == null ? 0 : int.parse(m.group(1)!);
  }
}

Course _parseCourse(String json) =>
    Course.fromJson(jsonDecode(json) as Map<String, dynamic>);
