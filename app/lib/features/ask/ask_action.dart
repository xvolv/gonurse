import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';
import '../../models/course.dart';
import 'ai_target.dart';
import 'prompt_templates.dart';

/// Opens a URL outside the app (the AI's app if installed, else the
/// browser). A provider so tests can replace it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The lines she asked about, highlighted when she comes back to the app.
class AskPending {
  static const _key = 'ask_pending';

  final String noteId;
  final Set<int> lines;

  const AskPending(this.noteId, this.lines);

  static AskPending? read(Box box) {
    final m = box.get(_key) as Map?;
    if (m == null) return null;
    return AskPending(m['note'] as String, {
      for (final n in m['lines'] as List? ?? [m['n']]) n as int,
    });
  }

  void save(Box box) =>
      box.put(_key, {'note': noteId, 'lines': lines.toList()});

  static void clear(Box box) => box.delete(_key);
}

/// [lines] are put in note order (by line number), whatever order she
/// selected them in.
String buildPrompt(
  String template,
  Course course,
  Note note,
  Iterable<Line> lines,
) {
  final ordered = lines.toList()..sort((a, b) => a.n.compareTo(b.n));
  return fillTemplate(
    template,
    topic: '${note.title} (${[course.course, ...note.path].join(' › ')})',
    text: joinLines([for (final l in ordered) l.text]),
  );
}

/// Copies the prompt for [lines], remembers them, and opens the chosen AI
/// (with the prompt filled in if it supports that; the copy is then a backup).
/// Call straight from the tap handler: the copy must start inside it.
Future<void> askAboutLines({
  required BuildContext context,
  required WidgetRef ref,
  required Course course,
  required Note note,
  required Iterable<Line> lines,
  required AskMode mode,
}) async {
  final prompt = buildPrompt(
    ref.read(promptTemplatesProvider)[mode]!,
    course,
    note,
    lines,
  );
  final target = ref.read(aiTargetProvider);
  final uri = target.uriFor(prompt);
  final prefilled = target.prefills(prompt);
  final copy = Clipboard.setData(ClipboardData(text: prompt));
  AskPending(note.id, {
    for (final l in lines) l.n,
  }).save(ref.read(uiBoxProvider));

  try {
    await copy;
  } catch (_) {
    // Only matters when she has to paste the prompt herself.
    if (!prefilled) {
      if (!context.mounted) return;
      final copied = await _showCopyDialog(context, prompt);
      if (!copied) return;
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          prefilled ? target.openedToast! : target.copiedToast,
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  await ref.read(urlOpenerProvider)(uri);
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
