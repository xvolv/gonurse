import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ask/prompt_templates.dart';

/// Edit one Ask AI prompt template, or reset it to the default.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.mode});

  final AskMode mode;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final _text = TextEditingController(
    text: ref.read(promptTemplatesProvider)[widget.mode],
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Without `{text}` the tapped line would never reach the AI.
  bool get _valid => _text.text.contains('{text}');

  void _save() {
    ref.read(promptTemplatesProvider.notifier).set(widget.mode, _text.text);
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(promptTemplatesProvider.notifier).reset(widget.mode);
    setState(() => _text.text = widget.mode.defaultTemplate);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.label),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Reset to default')),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '{topic} becomes the note title and where it is.\n'
                  '{text} becomes the line you tapped.',
                  style: TextStyle(fontSize: 14, color: muted),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _text,
                    onChanged: (_) => setState(() {}),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: _valid ? null : 'Keep {text} in the prompt',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _valid ? _save : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Save', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
