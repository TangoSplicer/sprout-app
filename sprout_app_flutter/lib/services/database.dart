import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class SproutDB {
  static final SproutDB _instance = SproutDB._internal();
  static final RegExp _identifierPattern =
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,62}$');
  static const _allowedColumnTypes = {
    'INTEGER',
    'REAL',
    'TEXT',
    'BLOB',
    'NUMERIC',
  };

  factory SproutDB() => _instance;

  SproutDB._internal();

  Database? _database;

  Future<Database> get db async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = path.join(databaseDirectory, 'sprout.db');
    return openDatabase(databasePath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database database, int version) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> createTable(String name, Map<String, String> fields) async {
    _requireIdentifier(name, 'table name');
    if (fields.isEmpty) {
      throw ArgumentError.value(
          fields, 'fields', 'At least one column is required');
    }

    final columns = fields.entries.map((entry) {
      _requireIdentifier(entry.key, 'column name');
      final type = entry.value.trim().toUpperCase();
      if (!_allowedColumnTypes.contains(type)) {
        throw ArgumentError.value(
            entry.value, entry.key, 'Unsupported SQLite column type');
      }
      return '${entry.key} $type';
    }).join(', ');

    final database = await db;
    await database.execute(
      'CREATE TABLE IF NOT EXISTS $name (id INTEGER PRIMARY KEY, $columns)',
    );
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _requireIdentifier(table, 'table name');
    final database = await db;
    return database.query(table, where: where, whereArgs: whereArgs);
  }

  Future<void> insert(String table, Map<String, Object?> data) async {
    _requireIdentifier(table, 'table name');
    _validateDataKeys(data);
    final database = await db;
    await database.insert(table, data);
  }

  Future<void> update(
    String table,
    Map<String, Object?> data,
    String where, {
    List<Object?>? whereArgs,
  }) async {
    _requireIdentifier(table, 'table name');
    _validateDataKeys(data);
    final database = await db;
    await database.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<void> delete(
    String table,
    String where, {
    List<Object?>? whereArgs,
  }) async {
    _requireIdentifier(table, 'table name');
    final database = await db;
    await database.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  void _validateDataKeys(Map<String, Object?> data) {
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'At least one value is required');
    }
    for (final key in data.keys) {
      _requireIdentifier(key, 'column name');
    }
  }

  void _requireIdentifier(String value, String label) {
    if (!_identifierPattern.hasMatch(value)) {
      throw ArgumentError.value(value, label, 'Must be a safe SQL identifier');
    }
  }
}
