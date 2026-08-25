import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite schema + migrations for Open Scripture Voice (Architecture B).
///
/// `voice_packs` and `tts_cache` are the two tables that make "what audio do
/// I have" a runtime question rather than a build-time one.
class AppDatabase {
  AppDatabase._();

  static const int schemaVersion = 1;
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'open_scripture_voice.db'),
      version: schemaVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        testament TEXT NOT NULL,
        name TEXT NOT NULL,
        abbrev TEXT NOT NULL,
        book_order INTEGER NOT NULL,
        chapter_count INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE verses (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL REFERENCES books(id),
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        normalized_text TEXT,
        pipeline_version INTEGER,
        UNIQUE(book_id, chapter, verse)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_verses_lookup ON verses(book_id, chapter)',
    );

    await db.execute('''
      CREATE TABLE voice_packs (
        id TEXT PRIMARY KEY,
        engine TEXT NOT NULL,
        language TEXT NOT NULL,
        display_name TEXT NOT NULL,
        size_bytes INTEGER,
        license TEXT,
        installed INTEGER NOT NULL DEFAULT 0,
        install_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tts_cache (
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        voice_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER,
        size_bytes INTEGER,
        generated_at TEXT NOT NULL,
        PRIMARY KEY (book_id, chapter, voice_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER,
        position_ms INTEGER,
        label TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        position_ms INTEGER,
        played_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }
}
