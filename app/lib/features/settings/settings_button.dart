import 'package:flutter/material.dart';

import 'settings_screen.dart';

/// Gear icon for app bars.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
  );
}
