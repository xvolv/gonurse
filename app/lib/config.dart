/// App-wide settings that may need changing without touching UI code.
library;

/// Public repo serving `version.json` and `<course>_notes.json` at its root.
const contentBaseUrl =
    'https://raw.githubusercontent.com/xvolv/gonurse-content/main/';

const deepSeekUrl = 'https://chat.deepseek.com/';

/// Source PDFs are bundled from the repo's `files/` folder (see ../pubspec.yaml).
const sourceFilesAssetDir = 'packages/gonurse_files/files/';

class CourseConfig {
  /// Key in `version.json`; the remote notes file is `<id>_notes.json`.
  final String id;

  /// Bundled copy, used until a newer version has been synced.
  final String asset;

  const CourseConfig(this.id, this.asset);

  String get remoteFile => '${id}_notes.json';
}

const courses = [
  CourseConfig('pharmacology', 'packages/gonurse_files/content/pharmacology_notes.json'),
];
