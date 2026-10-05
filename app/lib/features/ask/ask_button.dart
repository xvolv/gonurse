import 'package:flutter/material.dart';

import 'prompt_templates.dart';

/// App-bar button that sends the selected lines to the AI.
///
/// Greyed out until a line is selected; then shows how many. Tap sends with
/// "Explain in Amharic"; long-press picks another mode for this send only.
class AskAiButton extends StatelessWidget {
  const AskAiButton({
    super.key = const ValueKey('ask-ai'),
    required this.count,
    required this.label,
    required this.onSend,
  });

  /// Number of selected lines.
  final int count;

  /// Name of the AI it opens (ChatGPT or DeepSeek), for screen readers.
  final String label;
  final ValueChanged<AskMode> onSend;

  bool get _enabled => count > 0;

  Future<void> _chooseMode(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    final mode = await showMenu<AskMode>(
      context: context,
      position: position,
      items: [
        for (final m in AskMode.values)
          PopupMenuItem(
            value: m,
            height: 52,
            child: Text(m.label, style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
    if (mode != null) onSend(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: 'Ask $label about $count selected lines',
      child: InkResponse(
        radius: 24,
        onTap: _enabled ? () => onSend(AskMode.explain) : null,
        onLongPress: _enabled ? () => _chooseMode(context) : null,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Badge(
              isLabelVisible: _enabled,
              label: Text('$count'),
              child: Icon(
                Icons.auto_awesome,
                color: _enabled
                    ? colors.primary
                    : colors.onSurface.withAlpha(97), // ~38%: disabled
              ),
            ),
          ),
        ),
      ),
    );
  }
}
