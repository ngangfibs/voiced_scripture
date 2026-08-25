import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Seeds the bundled WEB text into SQLite on first launch.
///
/// Asset format (assets/bible/web/seed.json):
/// {
///   "books": [{"id":1,"testament":"OT","name":"Genesis","abbrev":"Gen",
///              "book_order":1,"chapter_count":50}, ...],
///   "verses": [{"book_id":1,"chapter":1,"verse":1,"text":"..."}, ...]
/// }
///
/// The full WEB text (public domain) is converted to this format by
/// tools/build_seed.py; the repo ships a Phase-1 sample (Genesis 1,
/// Psalm 23, John 3) until Phase 5 lands the full text.
class BibleSeeder {
  static const _seededKey = 'bible_seeded';

  static Future<void> seedIfNeeded() async {
    final db = await AppDatabase.instance();
    final rows = await db
        .query('settings', where: 'key = ?', whereArgs: [_seededKey], limit: 1);
    if (rows.isNotEmpty && rows.first['value'] == '1') return;

    final json =
        jsonDecode(await rootBundle.loadString('assets/bible/web/seed.json'))
            as Map<String, dynamic>;

    await db.transaction((txn) async {
      for (final b in json['books'] as List) {
        await txn.insert('books', (b as Map).cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final v in json['verses'] as List) {
        await txn.insert('verses', (v as Map).cast<String, Object?>(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('settings', {'key': _seededKey, 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
