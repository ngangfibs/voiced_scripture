/// Plain data models matching the SQLite schema.

class Book {
  final int id;
  final String testament; // 'OT' | 'NT'
  final String name;
  final String abbrev;
  final int bookOrder;
  final int chapterCount;

  const Book({
    required this.id,
    required this.testament,
    required this.name,
    required this.abbrev,
    required this.bookOrder,
    required this.chapterCount,
  });

  factory Book.fromRow(Map<String, Object?> r) => Book(
        id: r['id'] as int,
        testament: r['testament'] as String,
        name: r['name'] as String,
        abbrev: r['abbrev'] as String,
        bookOrder: r['book_order'] as int,
        chapterCount: r['chapter_count'] as int,
      );
}

class Verse {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String? normalizedText;
  final int? pipelineVersion;

  const Verse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.normalizedText,
    this.pipelineVersion,
  });

  factory Verse.fromRow(Map<String, Object?> r) => Verse(
        id: r['id'] as int,
        bookId: r['book_id'] as int,
        chapter: r['chapter'] as int,
        verse: r['verse'] as int,
        text: r['text'] as String,
        normalizedText: r['normalized_text'] as String?,
        pipelineVersion: r['pipeline_version'] as int?,
      );
}

class VoicePack {
  final String id; // e.g. 'piper-en-amy-low'
  final String engine; // 'piper' | 'kokoro' | 'pocket-tts'
  final String language;
  final String displayName;
  final int? sizeBytes;
  final String? license;
  final bool installed;
  final String? installPath;

  const VoicePack({
    required this.id,
    required this.engine,
    required this.language,
    required this.displayName,
    this.sizeBytes,
    this.license,
    this.installed = false,
    this.installPath,
  });

  factory VoicePack.fromRow(Map<String, Object?> r) => VoicePack(
        id: r['id'] as String,
        engine: r['engine'] as String,
        language: r['language'] as String,
        displayName: r['display_name'] as String,
        sizeBytes: r['size_bytes'] as int?,
        license: r['license'] as String?,
        installed: (r['installed'] as int) == 1,
        installPath: r['install_path'] as String?,
      );
}

class CachedChapter {
  final int bookId;
  final int chapter;
  final String voiceId;
  final String filePath;
  final int? durationMs;
  final int? sizeBytes;
  final DateTime generatedAt;

  const CachedChapter({
    required this.bookId,
    required this.chapter,
    required this.voiceId,
    required this.filePath,
    this.durationMs,
    this.sizeBytes,
    required this.generatedAt,
  });

  factory CachedChapter.fromRow(Map<String, Object?> r) => CachedChapter(
        bookId: r['book_id'] as int,
        chapter: r['chapter'] as int,
        voiceId: r['voice_id'] as String,
        filePath: r['file_path'] as String,
        durationMs: r['duration_ms'] as int?,
        sizeBytes: r['size_bytes'] as int?,
        generatedAt: DateTime.parse(r['generated_at'] as String),
      );
}

class Bookmark {
  final int? id;
  final int bookId;
  final int chapter;
  final int? verse;
  final int? positionMs;
  final String? label;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.bookId,
    required this.chapter,
    this.verse,
    this.positionMs,
    this.label,
    required this.createdAt,
  });
}
