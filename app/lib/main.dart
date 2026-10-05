import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/content_repository.dart';
import 'data/providers.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
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

class GoNurseApp extends StatelessWidget {
  const GoNurseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoNurse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D6B),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
