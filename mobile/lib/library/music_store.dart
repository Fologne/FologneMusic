import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

abstract class MusicStore {
  Future<List<Track>> readTracks();
  Future<void> writeTracks(List<Track> tracks);
  Future<Map<String, dynamic>> readState();
  Future<void> writeState(Map<String, dynamic> state);
}

class SqliteMusicStore implements MusicStore {
  SqliteMusicStore(this.db);
  final Database db;
  static Future<SqliteMusicStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'musicapp.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE tracks (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), data TEXT NOT NULL)',
        );
      },
    );
    return SqliteMusicStore(db);
  }

  @override
  Future<List<Track>> readTracks() async => (await db.query('tracks'))
      .map(
        (row) => Track.fromJson(
          jsonDecode(row['data'] as String) as Map<String, dynamic>,
        ),
      )
      .toList();
  @override
  Future<void> writeTracks(List<Track> tracks) => db.transaction((txn) async {
    final batch = txn.batch();
    batch.delete('tracks');
    for (final track in tracks) {
      batch.insert('tracks', {
        'id': track.id,
        'data': jsonEncode(track.toJson()),
      });
    }
    await batch.commit(noResult: true);
  });
  @override
  Future<Map<String, dynamic>> readState() async {
    final rows = await db.query('state', where: 'id = 1');
    return rows.isEmpty
        ? {}
        : jsonDecode(rows.single['data'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> writeState(Map<String, dynamic> state) async {
    await db.insert('state', {
      'id': 1,
      'data': jsonEncode(state),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
