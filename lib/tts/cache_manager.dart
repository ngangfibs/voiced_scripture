import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db/app_database.dart';
import '../data/models/models.dart';
import '../data/repositories/bible_repository.dart';
import 'engine_interface.dart';
import 'preprocessing/pronunciation_lexicon.dart';
import 'preprocessing/text_normalizer.dart';

/// Runtime synthesis + cache pipeline (Architecture B core).
///
/// Cache-first: check tts_cache for (book, chapter, voice); on miss,
/// preprocess each verse, synthesize verse-by-verse, stream finished verses
/// to the caller as they complete, and write audio to the cache directory.
/// Playback speed is a player setting — cached audio is synthesized once at
/// speed 1.0 and rate-shifted by just_audio.
class TtsCacheManager {
  final TtsEngine engine;
  final BibleRepository bible;
  final TextNormalizer normalizer;
  final PronunciationLexicon lexicon;

  /// Hard ceiling for the cache on storage-constrained phones.
  /// Oldest entries are evicted first. Configurable from Settings.
  int maxCacheBytes;

  TtsCacheManager({
    required this.engine,
    required this.bible,
    required this.normalizer,
    required this.lexicon,
    this.maxCacheBytes = 500 * 1024 * 1024, // 500MB default cap
  });

  Future<Database> get _db async => AppDatabase.instance();

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'tts_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<CachedChapter?> lookup(int bookId, int chapter, String voiceId) async {
    final rows = await (await _db).query(
      'tts_cache',
      where: 'book_id = ? AND chapter = ? AND voice_id = ?',
      whereArgs: [bookId, chapter, voiceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final entry = CachedChapter.fromRow(rows.first);
    // Treat a missing file as a miss.
    if (!File(entry.filePath).existsSync()) {
      await (await _db).delete(
        'tts_cache',
        where: 'book_id = ? AND chapter = ? AND voice_id = ?',
        whereArgs: [bookId, chapter, voiceId],
      );
      return null;
    }
    return entry;
  }

  /// Synthesizes a chapter verse-by-verse. Yields each verse's audio as it
  /// completes so playback can start after the first verse. Writes finished
  /// audio to the cache; marks the chapter cached once the last verse lands.
  Stream<VerseSynthesisResult> synthesizeChapter({
    required int bookId,
    required int chapter,
    required String voiceId,
  }) async* {
    final verses = await bible.chapter(bookId, chapter);
    final dir = await _cacheDir();
    final chapterDir = Directory(
        p.join(dir.path, voiceId, bookId.toString(), chapter.toString()));
    if (!chapterDir.existsSync()) chapterDir.createSync(recursive: true);

    var totalBytes = 0;
    var totalMs = 0;

    for (final verse in verses) {
      // Cached normalized text unless the pipeline version moved on.
      var normalized = verse.normalizedText;
      if (normalized == null ||
          verse.pipelineVersion != TextNormalizer.pipelineVersion) {
        normalized = normalizer.process(verse.text);
        if (normalized == null) continue;
        await bible.saveNormalizedText(
            verse.id, normalized, TextNormalizer.pipelineVersion);
      }
      final spoken = lexicon.apply(normalized);

      final audio = await engine.synthesize(spoken);
      final file = File(p.join(chapterDir.path, 'verse_${verse.verse}.wav'));
      final wavBytes = _encodeWav(audio);
      await file.writeAsBytes(wavBytes, flush: true);

      totalBytes += wavBytes.length;
      totalMs += (audio.samples.length / audio.sampleRate * 1000).round();

      yield VerseSynthesisResult(
        verse: verse.verse,
        filePath: file.path,
        durationMs: (audio.samples.length / audio.sampleRate * 1000).round(),
      );
    }

    await (await _db).insert(
      'tts_cache',
      {
        'book_id': bookId,
        'chapter': chapter,
        'voice_id': voiceId,
        'file_path': chapterDir.path,
        'duration_ms': totalMs,
        'size_bytes': totalBytes,
        'generated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _evictIfOverCap();
  }

  /// Pre-warms the cache for a whole book (or call per book for the whole
  /// Bible) — the "make available offline" action. Once cached, playback is
  /// indistinguishable from a pre-bundled audio app.
  Future<void> prewarmBook(int bookId, String voiceId,
      {void Function(int chapter, int total)? onProgress}) async {
    final book = await bible.book(bookId);
    if (book == null) return;
    for (var ch = 1; ch <= book.chapterCount; ch++) {
      final hit = await lookup(bookId, ch, voiceId);
      if (hit == null) {
        await synthesizeChapter(bookId: bookId, chapter: ch, voiceId: voiceId)
            .drain();
      }
      onProgress?.call(ch, book.chapterCount);
    }
  }

  Future<int> cacheSizeBytes() async {
    final rows = await (await _db)
        .rawQuery('SELECT COALESCE(SUM(size_bytes), 0) AS total FROM tts_cache');
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    await (await _db).delete('tts_cache');
  }

  Future<void> _evictIfOverCap() async {
    var total = await cacheSizeBytes();
    if (total <= maxCacheBytes) return;
    final rows = await (await _db)
        .query('tts_cache', orderBy: 'generated_at ASC');
    for (final row in rows) {
      if (total <= maxCacheBytes) break;
      final entry = CachedChapter.fromRow(row);
      final dir = Directory(entry.filePath);
      if (dir.existsSync()) await dir.delete(recursive: true);
      await (await _db).delete(
        'tts_cache',
        where: 'book_id = ? AND chapter = ? AND voice_id = ?',
        whereArgs: [entry.bookId, entry.chapter, entry.voiceId],
      );
      total -= entry.sizeBytes ?? 0;
    }
  }

  /// Minimal 16-bit PCM WAV encoder (sherpa returns float samples in [-1,1]).
  List<int> _encodeWav(SynthesizedAudio audio) {
    final samples = audio.samples;
    final dataLen = samples.length * 2;
    final byteRate = audio.sampleRate * 2;
    final out = ByteData(44 + dataLen);

    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        out.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    out.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, audio.sampleRate, Endian.little);
    out.setUint32(28, byteRate, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    out.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final s = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      out.setInt16(44 + i * 2, s, Endian.little);
    }
    return out.buffer.asUint8List();
  }
}

class VerseSynthesisResult {
  final int verse;
  final String filePath;
  final int durationMs;

  const VerseSynthesisResult({
    required this.verse,
    required this.filePath,
    required this.durationMs,
  });
}
