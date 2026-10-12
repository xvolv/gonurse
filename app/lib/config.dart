/// App-wide settings that may need changing without touching UI code.
library;

/// Public repo serving `version.json` and `<course>_notes.json` at its root.
/// The keys of `version.json` are the courses.
const contentBaseUrl =
    'https://raw.githubusercontent.com/xvolv/gonurse-content/main/';

/// Bundled copy of the same files, for the first launch offline
/// (the repo's `content/` folder, see ../pubspec.yaml).
const bundledContentDir = 'packages/gonurse_files/content/';

/// Chat sites for Ask AI (see `features/ask/ai_target.dart`).
const chatGptUrl = 'https://chatgpt.com/';
const deepSeekUrl = 'https://chat.deepseek.com/';

/// Source PDFs are bundled from the repo's `files/` folder (see ../pubspec.yaml).
const sourceFilesAssetDir = 'packages/gonurse_files/files/';

/// The notes file of a course, both bundled and on the server.
String notesFile(String courseId) => '${courseId}_notes.json';
