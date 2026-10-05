import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'data/content_repository.dart';
import 'data/providers.dart';
import 'data/settings.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App data goes in the app-support folder (AppData on Windows), not in
  // Documents, which is often synced by OneDrive.
  Hive.init((await getApplicationSupportDirectory()).path);
  final contentBox = await Hive.openBox(ContentRepository.boxName);
  final uiBox = await Hive.openBox('ui');

  runApp(
    ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          ContentRepository(contentBox, loadAsset: rootBundle.loadString),
        ),
        uiBoxProvider.overrideWithValue(uiBox),
      ],
      child: const GoNurseApp(),
    ),
  );
}

class GoNurseApp extends ConsumerWidget {
  const GoNurseApp({super.key});

  static const _seed = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'GoNurse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ref.watch(darkThemeProvider)
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
