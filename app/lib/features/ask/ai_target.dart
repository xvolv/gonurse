import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../data/providers.dart';

/// The AI site Ask mode opens. She picks one in Settings.
enum AiTarget {
  /// Opens with the prompt already filled in (`?q=`).
  chatGpt(
    'ChatGPT',
    chatGptUrl,
    prefillParam: 'q',
    // "Opened in ChatGPT."
    openedToast: 'ChatGPT ላይ ተከፍቷል',
    // "Copied. Paste it in ChatGPT and send."
    copiedToast: 'ተቀድቷል። ChatGPT ላይ Paste አድርገሽ ላኪ',
  ),

  deepSeek(
    'DeepSeek',
    deepSeekUrl,
    copiedToast: 'ተቀድቷል። DeepSeek ላይ Paste አድርገሽ ላኪ',
  );

  const AiTarget(
    this.label,
    this.url, {
    this.prefillParam,
    this.openedToast,
    required this.copiedToast,
  });

  final String label;
  final String url;

  /// Query parameter that pre-fills the prompt, if the site supports one.
  final String? prefillParam;

  /// Toast when the site opens with the prompt filled in.
  final String? openedToast;

  /// Toast when she has to paste the prompt herself.
  final String copiedToast;

  /// Longest pre-filled link; longer prompts are pasted instead.
  static const maxPrefillUrlLength = 6000;

  /// The link to open, with the prompt filled in when possible.
  Uri uriFor(String prompt) {
    if (prefillParam != null) {
      final prefilled = '$url?$prefillParam=${Uri.encodeComponent(prompt)}';
      if (prefilled.length <= maxPrefillUrlLength) return Uri.parse(prefilled);
    }
    return Uri.parse(url);
  }

  bool prefills(String prompt) => uriFor(prompt).hasQuery;
}

final aiTargetProvider = NotifierProvider<AiTargetNotifier, AiTarget>(
  AiTargetNotifier.new,
);

class AiTargetNotifier extends Notifier<AiTarget> {
  static const _key = 'ai_target';

  @override
  AiTarget build() {
    final saved = ref.read(uiBoxProvider).get(_key) as String?;
    return AiTarget.values.where((t) => t.name == saved).firstOrNull ??
        AiTarget.chatGpt;
  }

  void set(AiTarget target) {
    ref.read(uiBoxProvider).put(_key, target.name);
    state = target;
  }
}
