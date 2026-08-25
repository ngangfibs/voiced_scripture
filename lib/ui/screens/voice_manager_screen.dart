import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/repositories/voice_pack_repository.dart';
import '../../service_locator.dart';

/// Voice & Language Pack Manager: bundled and downloadable voices/engines
/// with size and license, install/delete, set default.
class VoiceManagerScreen extends StatefulWidget {
  final VoicePackRepository repo;
  const VoiceManagerScreen({super.key, required this.repo});

  @override
  State<VoiceManagerScreen> createState() => _VoiceManagerScreenState();
}

class _VoiceManagerScreenState extends State<VoiceManagerScreen> {
  late Future<List<VoicePack>> _packs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _packs = widget.repo.all());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voices & Languages')),
      body: FutureBuilder<List<VoicePack>>(
        future: _packs,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              for (final pack in snap.data!)
                ListTile(
                  leading: Icon(pack.installed
                      ? Icons.check_circle
                      : Icons.download),
                  title: Text(pack.displayName),
                  subtitle: Text(
                    '${pack.engine} · ${pack.language}'
                    '${pack.sizeBytes != null ? ' · ${(pack.sizeBytes! / 1048576).toStringAsFixed(0)} MB' : ''}'
                    '${pack.license != null ? '\nLicense: ${pack.license}' : ''}',
                  ),
                  isThreeLine: pack.license != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (Services.activeVoiceId == pack.id)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Default'),
                        ),
                      if (pack.installed) ...[
                        IconButton(
                          icon: const Icon(Icons.star_border),
                          tooltip: 'Set default',
                          onPressed: () async {
                            await Services.setActiveVoice(pack.id);
                            _reload();
                          },
                        ),
                        if (pack.engine != 'piper') // bundled default stays
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await Services.deleteVoicePack(pack.id);
                              _reload();
                            },
                          ),
                      ] else
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Install',
                          onPressed: () async {
                            await Services.installVoicePack(pack.id);
                            _reload();
                          },
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
