// flutter/lib/services/database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SproutDB {
  static final SproutDB _instance = SproutDB._internal();
  factory SproutDB() => _instance;
  SproutDB._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final documents = await getDatabasesPath();
    final path = p.join(documents, 'sprout.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tables will be created on first use
  }

  Future<void> createTable(String name, Map<String, String> fields) async {
    final db = await this.db;
    final columns = fields.entries.map((e) => '${e.key} ${e.value}').join(', ');
    await db.execute('CREATE TABLE IF NOT EXISTS $name (id INTEGER PRIMARY KEY, $columns)');
  }

  Future<List<Map<String, Object?>>> query(String table, {String? where}) async {
    final db = await this.db;
    return await db.query(table, where: where);
  }

  Future<void> insert(String table, Map<String, Object?> data) async {
    final db = await this.db;
    await db.insert(table, data);
  }

  Future<void> update(String table, Map<String, Object?> data, String where) async {
    final db = await this.db;
    await db.update(table, data, where: where);
  }

  Future<void> delete(String table, String where) async {
    final db = await this.db;
    await db.delete(table, where: where);
  }
}