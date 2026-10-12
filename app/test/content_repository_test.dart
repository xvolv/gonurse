import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/content_repository.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A copy of a real notes file with a different version and course name,
/// so tests can tell which copy was loaded.
String notesJson(String id, {required int version, required String name}) {
  final json =
      jsonDecode(File('../content/${id}_notes.json').readAsStringSync())
          as Map<String, dynamic>;
  return jsonEncode({...json, 'version': version, 'course': name});
}

void main() {
  late Directory dir;
  late Box box;
  final requested = <String>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gonurse_test');
    Hive.init(dir.path);
    box = await Hive.openBox(ContentRepository.boxName);
    requested.clear();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  /// An app that bundles only Pharmacology, at [bundledVersion].
  ContentRepository repo({
    required http.Client client,
    int bundledVersion = 1,
  }) => ContentRepository(
    box,
    loadAsset: (asset) async => switch (asset) {
      '${bundledContentDir}version.json' => '{"pharmacology": $bundledVersion}',
      '${bundledContentDir}pharmacology_notes.json' => notesJson(
        'pharmacology',
        version: bundledVersion,
        name: 'Bundled',
      ),
      _ => throw StateError('no asset $asset'),
    },
    client: client,
  );

  /// Serves `version.json` with [versions] and a notes file named 'Remote'.
  MockClient server(Map<String, int> versions) => MockClient((req) async {
    final file = req.url.pathSegments.last;
    requested.add(file);
    if (file == 'version.json') return http.Response(jsonEncode(versions), 200);
    for (final MapEntry(key: id, value: v) in versions.entries) {
      if (file == notesFile(id)) {
        return http.Response.bytes(
          utf8.encode(notesJson(id, version: v, name: 'Remote $id')),
          200,
        );
      }
    }
    return http.Response('', 404);
  });

  final offline = MockClient(
    (_) async => throw const SocketException('offline'),
  );

  test('first launch offline uses the bundled notes', () async {
    final r = repo(client: offline);
    expect(await r.courseIds(), ['pharmacology']);
    final course = (await r.load('pharmacology'))!;
    expect(course.course, 'Bundled');
    expect(course.noteCount, 51);
    await expectLater(r.sync(), throwsA(isA<SocketException>()));
  });

  test(
    'newer remote version is downloaded, stored and used offline later',
    () async {
      final r = repo(client: server({'pharmacology': 2}));
      await r.load('pharmacology');
      expect(await r.sync(), ['pharmacology']);
      expect(r.localVersion('pharmacology'), 2);

      final later = repo(client: offline);
      expect((await later.load('pharmacology'))!.course, 'Remote pharmacology');
    },
  );

  test('same remote version: notes are not downloaded', () async {
    final r = repo(client: server({'pharmacology': 1}));
    await r.load('pharmacology');
    expect(await r.sync(), isEmpty);
    expect(requested, ['version.json']);
  });

  test('a broken download keeps the current notes', () async {
    final r = repo(
      client: MockClient(
        (req) async => req.url.path.endsWith('version.json')
            ? http.Response('{"pharmacology": 5}', 200)
            : http.Response('{"course": "half a fi', 200),
      ),
    );
    await r.load('pharmacology');
    await expectLater(r.sync(), throwsA(anything));
    expect(r.localVersion('pharmacology'), 1);
    expect((await r.load('pharmacology'))!.course, 'Bundled');
  });

  test(
    'a newer bundled copy (app update) wins over older stored notes',
    () async {
      final r = repo(client: server({'pharmacology': 2}));
      await r.load('pharmacology');
      await r.sync();

      final updatedApp = repo(client: offline, bundledVersion: 3);
      expect((await updatedApp.load('pharmacology'))!.course, 'Bundled');
      expect(updatedApp.localVersion('pharmacology'), 3);
    },
  );

  test('a new key on the server is downloaded and becomes a course', () async {
    final r = repo(client: server({'pharmacology': 1, 'medsurg': 1}));
    expect(await r.load('medsurg'), isNull, reason: 'not on the device yet');
    expect(await r.sync(), ['medsurg']);
    expect(requested, ['version.json', 'medsurg_notes.json']);

    // Later, offline: it is still listed and loads.
    final later = repo(client: offline);
    expect(await later.courseIds(), ['pharmacology', 'medsurg']);
    final medsurg = (await later.load('medsurg'))!;
    expect(medsurg.course, 'Remote medsurg');
    expect(medsurg.noteCount, 47);
  });

  test('the real bundled version.json: both courses, from the files', () async {
    final r = ContentRepository(
      box,
      loadAsset: (asset) async => File(
        '../content/${asset.substring(bundledContentDir.length)}',
      ).readAsString(),
      client: offline,
    );
    expect(await r.courseIds(), ['pharmacology', 'medsurg']);
    expect((await r.load('pharmacology'))!.noteCount, 51);
    expect((await r.load('medsurg'))!.course, 'Medical-Surgical Nursing');
  });
}
