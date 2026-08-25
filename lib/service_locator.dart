import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'data/db/app_database.dart';
import 'data/models/models.dart';
import 'data/repositories/bible_repository.dart';
import 'data/repositories/voice_pack_repository.dart';
import 'player/audio_service_handler.dart';
import 'player/playback_controller.dart';
import 'tts/cache_manager.dart';
import 'tts/preprocessing/lexicon_loader.dart';
import 'tts/preprocessing/text_normalizer.dart';
import 'tts/sherpa_engine.dart';

/// Minimal hand-rolled service wiring (keeps dependencies at the project's
/// minimal ethos — no DI framework).
class Services {
  static late final BibleRepository bible;
  static late final VoicePackRepository voicePacks;
  static late final SherpaEngine engine;
  static late final TtsCacheManager cache;
  static late final ScriptureAudioHandler audioHandler;
  static late final PlaybackController playback;

  static String activeVoiceId = 'piper-en-default';

  static Future<void> init() async {
    bible = BibleRepository();
    voicePacks = VoicePackRepository();
    engine = SherpaEngine();
    final lexicon = await loadLexiconFromAsset();
    cache = TtsCacheManager(
      engine: engine,
      bible: bible,
      normalizer: TextNormalizer(),
      lexicon: lexicon,
      maxCacheBytes: (await getCacheCapMb()) * 1024 * 1024,
    );
    audioHandler = ScriptureAudioHandler();
    playback = PlaybackController(cache: cache, bible: bible, audio: audioHandler);

    await _seedVoiceCatalog();

    // Load the bundled default voice (copied from assets on first launch).
    // Failure here must never crash the app — the user gets a clear message
    // on the Voices tab instead.
    final pack = await voicePacks.byId(activeVoiceId);
    if (pack != null && pack.installed && pack.installPath != null) {
      try {
        await engine.load(pack.installPath!);
      } catch (_) {
        // Engine stays unloaded; playback will surface a friendly error.
      }
    }
  }

  /// Catalog of downloadable voice packs. The bundled Piper voice is the
  /// always-available floor; everything else is an explicit one-time
  /// download (or sideload) and then permanently local.
  ///
  /// - Piper voices run on anything (the 4GB floor); Kokoro is the natural
  ///   "calm storyteller" tier for 4–6GB+ devices.
  /// - [voiceSid] selects the voice inside multi-speaker packs (Kokoro).
  /// - Chatterbox is intentionally absent: sherpa-onnx does not support it
  ///   (k2-fsa/sherpa-onnx#2271); Chatterbox-Nano support is an open
  ///   request (#3854). Add it here if that lands.
  static const voiceSid = {
    'kokoro-en-am-adam': 11, // verify against shipped voices.bin ordering
    'kokoro-en-af-heart': 4,
  };

  static Future<void> _seedVoiceCatalog() async {
    const catalog = [
      // Bundled default — always works, even on the weakest devices.
      VoicePack(
        id: 'piper-en-default',
        engine: 'piper',
        language: 'en',
        displayName: 'English (Piper, bundled)',
        sizeBytes: 65000000,
        license: 'Check per-voice terms; Piper engine is GPL-3.0',
        installed: true,
        installPath: 'assets/voices/piper-en-default',
      ),
      // Piper downloads — small, fast, run everywhere.
      VoicePack(
        id: 'piper-en-lessac-high',
        engine: 'piper',
        language: 'en-US',
        displayName: 'English — Lessac (male, clear)',
        sizeBytes: 120000000,
        license: 'Check per-voice terms; Piper engine is GPL-3.0',
      ),
      VoicePack(
        id: 'piper-en-ryan-high',
        engine: 'piper',
        language: 'en-US',
        displayName: 'English — Ryan (male, deep)',
        sizeBytes: 120000000,
        license: 'Check per-voice terms; Piper engine is GPL-3.0',
      ),
      VoicePack(
        id: 'piper-en-amy-medium',
        engine: 'piper',
        language: 'en-US',
        displayName: 'English — Amy (female)',
        sizeBytes: 65000000,
        license: 'Check per-voice terms; Piper engine is GPL-3.0',
      ),
      // Kokoro downloads — the natural-sounding tier.
      VoicePack(
        id: 'kokoro-en-am-adam',
        engine: 'kokoro',
        language: 'en-US',
        displayName: 'English — Adam (Kokoro, natural male)',
        sizeBytes: 110000000,
        license: 'Apache-2.0 weights; G2P espeak-ng fallback unresolved',
      ),
      VoicePack(
        id: 'kokoro-en-af-heart',
        engine: 'kokoro',
        language: 'en-US',
        displayName: 'English — Heart (Kokoro, natural female)',
        sizeBytes: 110000000,
        license: 'Apache-2.0 weights; G2P espeak-ng fallback unresolved',
      ),
    ];
    for (final pack in catalog) {
      final existing = await voicePacks.byId(pack.id);
      if (existing == null) await voicePacks.upsert(pack);
    }
  }

  static Future<Database> get _db async => AppDatabase.instance();

  static Future<int> getCacheCapMb() async {
    final rows = await (await _db)
        .query('settings', where: 'key = ?', whereArgs: ['cache_cap_mb']);
    return int.tryParse(rows.firstOrNull?['value'] as String? ?? '') ?? 500;
  }

  static Future<void> setCacheCapMb(int mb) async {
    await (await _db).insert(
      'settings',
      {'key': 'cache_cap_mb', 'value': '$mb'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    cache.maxCacheBytes = mb * 1024 * 1024;
  }

  static Future<void> setActiveVoice(String id) async {
    activeVoiceId = id;
    await (await _db).insert(
      'settings',
      {'key': 'active_voice', 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final pack = await voicePacks.byId(id);
    if (pack != null && pack.installed && pack.installPath != null) {
      // Multi-speaker models: pick the voice inside the pack (Kokoro's
      // voices.bin ordering differs between releases — verify the sid).
      engine.speakerId = voiceSid[id] ?? 0;
      try {
        await engine.load(pack.installPath!);
      } catch (_) {
        // Leave engine unloaded; playback shows a friendly error.
      }
    }
  }

  /// Installs a voice pack from local storage (sideloaded via
  /// Bluetooth/USB/memory card — no network required or used).
  static Future<void> installVoicePack(String id) async {
    final pickerPath = await _pickPackDirectory();
    if (pickerPath == null) return;
    await voicePacks.markInstalled(id, pickerPath);
  }

  static Future<void> deleteVoicePack(String id) async {
    final pack = await voicePacks.byId(id);
    if (pack?.installPath != null) {
      final dir = Directory(pack!.installPath!);
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    await voicePacks.markDeleted(id);
  }

  static Future<String?> _pickPackDirectory() async {
    // Platform file/directory picker wired in the Android layer; packs are
    // plain folders, so any local-transfer source works.
    final base = await getApplicationDocumentsDirectory();
    final incoming = Directory(p.join(base.path, 'incoming_packs'));
    return incoming.existsSync() ? incoming.path : null;
  }

  static Future<void> addBookmark({
    required int bookId,
    required int chapter,
    int? positionMs,
  }) async {
    await (await _db).insert('bookmarks', {
      'book_id': bookId,
      'chapter': chapter,
      'position_ms': positionMs,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> prewarmDialog(BuildContext context) async {
    final books = await bible.books();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          for (final b in books)
            ListTile(
              title: Text(b.name),
              subtitle: Text('${b.chapterCount} chapters'),
              onTap: () {
                Navigator.pop(sheetContext);
                cache.prewarmBook(b.id, activeVoiceId);
              },
            ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
