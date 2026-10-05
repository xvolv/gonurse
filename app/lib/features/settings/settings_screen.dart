import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_repository.dart';
import '../../data/providers.dart';
import '../../data/settings.dart';
import '../ask/ai_target.dart';
import '../ask/prompt_templates.dart';
import 'template_editor_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checking = false;

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    final result = await ref.read(coursesProvider.notifier).checkForUpdates();
    if (!mounted) return;
    setState(() => _checking = false);
    final message = switch (result) {
      SyncResult.updated => 'Your notes were updated.',
      SyncResult.upToDate => 'Your notes are up to date.',
      SyncResult.offline => 'No internet. Your saved notes still work.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textSize = ref.watch(textSizeProvider);
    final templates = ref.watch(promptTemplatesProvider);
    final courses = ref.watch(coursesProvider).valueOrNull ?? const [];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header('Reading'),
              _Padded(
                label: 'Text size',
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Normal')),
                    ButtonSegment(value: 1, label: Text('Large')),
                    ButtonSegment(value: 2, label: Text('Extra large')),
                  ],
                  selected: {textSize},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(textSizeProvider.notifier).set(s.single),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'The failing heart is a tired pump.',
                  style: TextStyle(
                    fontSize: ref.watch(bodyFontSizeProvider),
                    height: 1.5,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: const Text('Dark theme'),
                value: ref.watch(darkThemeProvider),
                onChanged: (v) => ref.read(darkThemeProvider.notifier).set(v),
              ),

              const _Header('Ask AI'),
              _Padded(
                label: 'AI for explanations',
                child: SegmentedButton<AiTarget>(
                  segments: [
                    for (final t in AiTarget.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {ref.watch(aiTargetProvider)},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(aiTargetProvider.notifier).set(s.single),
                ),
              ),
              for (final mode in AskMode.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  minTileHeight: 56,
                  leading: const Icon(Icons.edit_note),
                  title: Text('Prompt: ${mode.label}'),
                  subtitle: Text(
                    templates[mode] == mode.defaultTemplate
                        ? 'Default'
                        : 'Edited',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TemplateEditorScreen(mode: mode),
                    ),
                  ),
                ),

              const _Header('Notes'),
              for (final entry in courses)
                if (entry.course != null)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(entry.config.title),
                    subtitle: Text(
                      'Version ${entry.course!.version} · '
                      '${entry.course!.noteCount} notes',
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: _checking ? null : _checkForUpdates,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Check for updated notes'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Notes also update by themselves when the app starts '
                  'with internet.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// A label with a control under it.
class _Padded extends StatelessWidget {
  const _Padded({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}
