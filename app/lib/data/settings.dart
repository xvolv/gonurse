import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Reader text size: 0 = normal, 1 = large, 2 = extra large.
final textSizeProvider =
    NotifierProvider<TextSizeNotifier, int>(TextSizeNotifier.new);

class TextSizeNotifier extends Notifier<int> {
  static const _key = 'text_size';

  /// Body font size for each step (never below 16sp).
  static const bodySizes = [16.0, 18.0, 21.0];

  @override
  int build() => ref.read(uiBoxProvider).get(_key, defaultValue: 1) as int;

  void set(int step) {
    state = step.clamp(0, bodySizes.length - 1);
    ref.read(uiBoxProvider).put(_key, state);
  }
}

final bodyFontSizeProvider = Provider<double>(
    (ref) => TextSizeNotifier.bodySizes[ref.watch(textSizeProvider)]);
