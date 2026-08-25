import 'package:flutter/material.dart';

import '../../service_locator.dart';

/// Settings, including the Cache Manager: current size, clear, and a cap
/// ("keep at most N MB, evict oldest first").
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheBytes = 0;
  int _capMb = 500;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await Services.cache.cacheSizeBytes();
    final cap = await Services.getCacheCapMb();
    setState(() {
      _cacheBytes = bytes;
      _capMb = cap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Synthesis cache',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('Cache size'),
            subtitle:
                Text('${(_cacheBytes / 1048576).toStringAsFixed(1)} MB used'),
          ),
          ListTile(
            title: const Text('Cache limit'),
            subtitle: Text('Keep at most $_capMb MB, evict oldest first'),
            trailing: DropdownButton<int>(
              value: _capMb,
              items: const [
                DropdownMenuItem(value: 200, child: Text('200 MB')),
                DropdownMenuItem(value: 500, child: Text('500 MB')),
                DropdownMenuItem(value: 1000, child: Text('1 GB')),
                DropdownMenuItem(value: 2000, child: Text('2 GB')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await Services.setCacheCapMb(v);
                _load();
              },
            ),
          ),
          ListTile(
            title: const Text('Clear cache'),
            subtitle: const Text(
                'Deletes all synthesized audio. It will be regenerated on next listen.'),
            trailing: TextButton(
              onPressed: () async {
                await Services.cache.clearCache();
                _load();
              },
              child: const Text('Clear'),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Make available offline'),
            subtitle: const Text(
                'Pre-synthesize a book (or the whole Bible) while charging — then it plays instantly, forever.'),
            trailing: const Icon(Icons.download_for_offline),
            onTap: () => Services.prewarmDialog(context),
          ),
        ],
      ),
    );
  }
}
