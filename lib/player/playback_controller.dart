import 'dart:async';

import '../data/repositories/bible_repository.dart';
import '../tts/cache_manager.dart';
import 'audio_service_handler.dart';

/// Orchestrates the cache-first playback flow:
///
///   cache HIT  -> enqueue cached verse files, play immediately
///   cache MISS -> show "synthesizing…", synthesize verse-by-verse,
///                 enqueue each as it lands, start playback on first verse
class PlaybackController {
  final TtsCacheManager cache;
  final BibleRepository bible;
  final ScriptureAudioHandler audio;

  final _synthesizing = StreamController<bool>.broadcast();
  Stream<bool> get synthesizing => _synthesizing.stream;

  /// User-presentable error messages (voice missing, synthesis failure,
  /// corrupt cache, ...). UI shows these as snackbars — never crashes.
  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  PlaybackController({
    required this.cache,
    required this.bible,
    required this.audio,
  });

  Future<void> playChapter({
    required int bookId,
    required int chapter,
    required String voiceId,
    required String bookName,
  }) async {
    try {
      await _playChapter(
          bookId: bookId, chapter: chapter, voiceId: voiceId, bookName: bookName);
    } catch (e) {
      // Any failure — missing voice, engine error, IO — becomes a message,
      // not a crash.
      _synthesizing.add(false);
      _errors.add(_friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('not loaded') || msg.contains('Voice pack not found')) {
      return 'No voice is installed. Open the Voices tab to install one.';
    }
    if (msg.contains('missing')) {
      return 'The voice pack is incomplete. Try reinstalling it.';
    }
    return 'Audio generation failed. Please try again.';
  }

  Future<void> _playChapter({
    required int bookId,
    required int chapter,
    required String voiceId,
    required String bookName,
  }) async {
    await audio.clearQueue();

    final hit = await cache.lookup(bookId, chapter, voiceId);
    if (hit != null) {
      _synthesizing.add(false);
      // Cached chapters store verse files in a per-chapter directory.
      final verses = await bible.chapter(bookId, chapter);
      for (final v in verses) {
        final path = '${hit.filePath}/verse_${v.verse}.wav';
        await audio.enqueueVerse(
          filePath: path,
          title: '$bookName $chapter:${v.verse}',
          verse: v.verse,
        );
      }
      await audio.play();
      return;
    }

    // Cache miss: synthesize, streaming verses into the queue as they land.
    _synthesizing.add(true);
    var first = true;
    await for (final result in cache.synthesizeChapter(
      bookId: bookId,
      chapter: chapter,
      voiceId: voiceId,
    )) {
      await audio.enqueueVerse(
        filePath: result.filePath,
        title: '$bookName $chapter:${result.verse}',
        verse: result.verse,
      );
      if (first) {
        first = false;
        _synthesizing.add(false);
        await audio.play();
      }
    }
    if (first) {
      // Nothing synthesized (all verses invalid) — reset the indicator.
      _synthesizing.add(false);
    }
  }

  Future<void> setSpeed(double speed) => audio.setSpeed(speed);

  /// Sleep timer: pauses after [minutes]; null cancels.
  Timer? _sleepTimer;
  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null) return;
    _sleepTimer = Timer(Duration(minutes: minutes), () => audio.pause());
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _synthesizing.close();
    await _errors.close();
  }
}
