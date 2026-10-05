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

  /// Name shown on the home screen.
  final String title;

  /// Bundled copy, used until a newer version has been synced. Courses
  /// without one show as "coming soon" until their notes are published in
  /// the content repo and downloaded.
  final String? asset;

  const CourseConfig(this.id, this.title, {this.asset});

  String get remoteFile => '${id}_notes.json';
}

/// All exit-exam courses, in the order shown on the home screen.
const courses = [
  CourseConfig('maternity', 'Maternity'),
  CourseConfig('first_aid', 'First Aid'),
  CourseConfig('gynecology', 'Gynecology'),
  CourseConfig('research', 'Research'),
  CourseConfig('medical_surgical', 'Medical-Surgical I & II'),
  CourseConfig('psychiatry', 'Psychiatry'),
  CourseConfig('fundamentals', 'Fundamentals of Nursing'),
  CourseConfig('nutrition', 'Nutrition'),
  CourseConfig('pediatrics', 'Pediatrics'),
  CourseConfig('community_health', 'Community Health'),
  CourseConfig('cdc', 'CDC (Communicable Disease Control)'),
  CourseConfig(
    'pharmacology',
    'Pharmacology',
    asset: 'packages/gonurse_files/content/pharmacology_notes.json',
  ),
];
