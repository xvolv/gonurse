import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../data/providers.dart';
import '../../models/course.dart';
import 'prompt_templates.dart';

/// "Copied. Paste it in DeepSeek and send."
const copiedToast = 'ተቀድቷል። DeepSeek ላይ Paste አድርገሽ ላኪ';

/// Opens a URL outside the app (the DeepSeek app if installed, else the
/// browser). A provider so tests can replace it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The line she asked about, highlighted when she comes back to the app.
class AskPending {
  static const _key = 'ask_pending';

  final String noteId;
  final int lineN;

  const AskPending(this.noteId, this.lineN);

  static AskPending? read(Box box) {
    final m = box.get(_key) as Map?;
    return m == null ? null : AskPending(m['note'] as String, m['n'] as int);
  }

  void save(Box box) => box.put(_key, {'note': noteId, 'n': lineN});

  static void clear(Box box) => box.delete(_key);
}

String buildPrompt(String template, Course course, Note note, Line line) =>
    fillTemplate(
      template,
      topic: '${note.title} (${[course.course, ...note.path].join(' › ')})',
      text: line.text,
    );

/// Copies the prompt for [line], remembers the line, and opens DeepSeek.
/// Call straight from the tap handler: the copy must start inside it.
Future<void> askAboutLine({
  required BuildContext context,
  required WidgetRef ref,
  required Course course,
  required Note note,
  required Line line,
  required AskMode mode,
}) async {
  final prompt = buildPrompt(
    ref.read(promptTemplatesProvider)[mode]!,
    course,
    note,
    line,
  );
  final copy = Clipboard.setData(ClipboardData(text: prompt));
  AskPending(note.id, line.n).save(ref.read(uiBoxProvider));

  try {
    await copy;
  } catch (_) {
    if (!context.mounted) return;
    final copied = await _showCopyDialog(context, prompt);
    if (!copied || !context.mounted) return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(copiedToast, style: TextStyle(fontSize: 16)),
        duration: Duration(seconds: 6),
      ),
    );
  await ref.read(urlOpenerProvider)(Uri.parse(deepSeekUrl));
}

/// Shown when the clipboard fails: she can select the prompt herself, or try
/// copying again. Returns true if the prompt was copied.
Future<bool> _showCopyDialog(BuildContext context, String prompt) async {
  final copied = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Copy this question'),
      content: SingleChildScrollView(
        child: SelectableText(prompt, style: const TextStyle(fontSize: 15)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: prompt));
              if (context.mounted) Navigator.pop(context, true);
            } catch (_) {
              // Still failing: she can select the text above by hand.
            }
          },
        ),
      ],
    ),
  );
  return copied ?? false;
}
