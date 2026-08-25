import 'package:flutter/material.dart';

import 'data/db/bible_seeder.dart';
import 'data/repositories/voice_pack_repository.dart';
import 'service_locator.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/voice_manager_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BibleSeeder.seedIfNeeded();
  await Services.init();
  runApp(const OpenScriptureVoiceApp());
}

class OpenScriptureVoiceApp extends StatelessWidget {
  const OpenScriptureVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Scripture Voice',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        // Accessible defaults: large text and touch targets throughout.
        visualDensity: VisualDensity.standard,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      LibraryScreen(bible: Services.bible),
      VoiceManagerScreen(repo: VoicePackRepository()),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.record_voice_over), label: 'Voices'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
