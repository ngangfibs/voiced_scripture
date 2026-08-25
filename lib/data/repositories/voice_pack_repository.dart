import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/models.dart';

/// Tracks bundled and downloadable voice/engine packs.
class VoicePackRepository {
  Future<Database> get _db async => AppDatabase.instance();

  Future<List<VoicePack>> all() async {
    final rows = await (await _db).query('voice_packs', orderBy: 'display_name');
    return rows.map(VoicePack.fromRow).toList();
  }

  Future<VoicePack?> byId(String id) async {
    final rows = await (await _db)
        .query('voice_packs', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : VoicePack.fromRow(rows.first);
  }

  Future<void> upsert(VoicePack pack) async {
    await (await _db).insert(
      'voice_packs',
      {
        'id': pack.id,
        'engine': pack.engine,
        'language': pack.language,
        'display_name': pack.displayName,
        'size_bytes': pack.sizeBytes,
        'license': pack.license,
        'installed': pack.installed ? 1 : 0,
        'install_path': pack.installPath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markInstalled(String id, String installPath) async {
    await (await _db).update(
      'voice_packs',
      {'installed': 1, 'install_path': installPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDeleted(String id) async {
    await (await _db).update(
      'voice_packs',
      {'installed': 0, 'install_path': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
