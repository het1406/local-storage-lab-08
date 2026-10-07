import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Reconstructed from the schema and API described in the activity guide.
class DatabaseHelper {
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      join(directory.path, 'MyDatabase.db'),
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $table (
          $columnId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnAge INTEGER NOT NULL
        )
      '''),
    );
  }

  Future<int> insert(Map<String, dynamic> row) => _db.insert(table, row);
  Future<List<Map<String, dynamic>>> queryAllRows() =>
      _db.query(table, orderBy: '$columnId ASC');
  Future<int> queryRowCount() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM $table'),
      ) ??
      0;
  Future<int> update(Map<String, dynamic> row) => _db.update(
    table,
    row,
    where: '$columnId = ?',
    whereArgs: [row[columnId] as int],
  );
  Future<int> delete(int id) =>
      _db.delete(table, where: '$columnId = ?', whereArgs: [id]);
}
