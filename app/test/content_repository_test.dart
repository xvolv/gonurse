import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gonurse/config.dart';
import 'package:gonurse/data/content_repository.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A copy of the real notes file with a different version and course name,
/// so tests can tell which copy was loaded.
String notesJson({required int version, required String name}) {
  final json =
      jsonDecode(File('../content/pharmacology_notes.json').readAsStringSync())
          as Map<String, dynamic>;
  return jsonEncode({...json, 'version': version, 'course': name});
}

void main() {
  final pharm = courses.firstWhere((c) => c.id == 'pharmacology');
  final firstAid = courses.firstWhere((c) => c.id == 'first_aid');
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

  ContentRepository repo({
    required http.Client client,
    int bundledVersion = 1,
  }) => ContentRepository(
    box,
    loadAsset: (_) async => notesJson(version: bundledVersion, name: 'Bundled'),
    client: client,
  );

  /// Serves `version.json` with [remoteVersion] and a notes file named 'Remote'.
  MockClient server(int remoteVersion) => MockClient((req) async {
    requested.add(req.url.pathSegments.last);
    return switch (req.url.pathSegments.last) {
      'version.json' => http.Response('{"pharmacology": $remoteVersion}', 200),
      'pharmacology_notes.json' => http.Response.bytes(
        utf8.encode(notesJson(version: remoteVersion, name: 'Remote')),
        200,
      ),
      _ => http.Response('', 404),
    };
  });

  final offline = MockClient(
    (_) async => throw const SocketException('offline'),
  );

  test('first launch offline uses the bundled notes', () async {
    final r = repo(client: offline);
    final course = (await r.load(pharm))!;
    expect(course.course, 'Bundled');
    expect(course.noteCount, 141);
    await expectLater(r.sync(), throwsA(isA<SocketException>()));
  });

  test(
    'newer remote version is downloaded, stored and used offline later',
    () async {
      final r = repo(client: server(2));
      await r.load(pharm);
      expect(await r.sync(), [pharm]);
      expect(r.localVersion(pharm), 2);

      final later = repo(client: offline);
      expect((await later.load(pharm))!.course, 'Remote');
    },
  );

  test('same remote version: notes are not downloaded', () async {
    final r = repo(client: server(1));
    await r.load(pharm);
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
    await r.load(pharm);
    await expectLater(r.sync(), throwsA(anything));
    expect(r.localVersion(pharm), 1);
    expect((await r.load(pharm))!.course, 'Bundled');
  });

  test(
    'a newer bundled copy (app update) wins over older stored notes',
    () async {
      final r = repo(client: server(2));
      await r.load(pharm);
      await r.sync();

      final updatedApp = repo(client: offline, bundledVersion: 3);
      expect((await updatedApp.load(pharm))!.course, 'Bundled');
      expect(updatedApp.localVersion(pharm), 3);
    },
  );

  test('a course without notes loads as null until it is published', () async {
    final r = repo(client: offline);
    expect(await r.load(firstAid), isNull);

    final online = repo(
      client: MockClient(
        (req) async => switch (req.url.pathSegments.last) {
          'version.json' => http.Response(
            '{"pharmacology": 1, "first_aid": 1}',
            200,
          ),
          'first_aid_notes.json' => http.Response.bytes(
            utf8.encode(notesJson(version: 1, name: 'First Aid')),
            200,
          ),
          _ => http.Response('', 404),
        },
      ),
    );
    for (final c in courses) {
      await online.load(c);
    }
    expect(await online.sync(), [firstAid]);
    expect((await r.load(firstAid))!.course, 'First Aid');
  });
}
