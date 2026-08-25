import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Read access to the bundled Bible text (WEB, public domain), seeded into
/// SQLite on first launch from assets/bible/web/.
class BibleRepository {
  Future<Database> get _db async => AppDatabase.instance();

  Future<List<Book>> books() async {
    final rows = await (await _db).query('books', orderBy: 'book_order');
    return rows.map(Book.fromRow).toList();
  }

  Future<Book?> book(int id) async {
    final rows = await (await _db)
        .query('books', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Book.fromRow(rows.first);
  }

  Future<List<Verse>> chapter(int bookId, int chapter) async {
    final rows = await (await _db).query(
      'verses',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'verse',
    );
    return rows.map(Verse.fromRow).toList();
  }

  /// Persists normalized text so preprocessing runs once per verse, and only
  /// re-runs when [pipelineVersion] changes.
  Future<void> saveNormalizedText(
      int verseId, String normalized, int pipelineVersion) async {
    await (await _db).update(
      'verses',
      {'normalized_text': normalized, 'pipeline_version': pipelineVersion},
      where: 'id = ?',
      whereArgs: [verseId],
    );
  }

  /// Offline search over raw verse text.
  Future<List<Verse>> search(String query, {int limit = 100}) async {
    final rows = await (await _db).query(
      'verses',
      where: 'text LIKE ?',
      whereArgs: ['%${query.replaceAll('%', '')}%'],
      limit: limit,
    );
    return rows.map(Verse.fromRow).toList();
  }
}
