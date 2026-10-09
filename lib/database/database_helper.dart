import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        imagePath TEXT
      )
    ''');
  }

  // Thêm khoản chi
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;

    return await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Lấy tất cả khoản chi
  Future<List<Expense>> getExpenses() async {
    final db = await instance.database;

    final result = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );

    return result.map((map) {
      return Expense.fromMap(map);
    }).toList();
  }

  // Lấy một khoản chi theo ID
  Future<Expense?> getExpense(int id) async {
    final db = await instance.database;

    final result = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Expense.fromMap(result.first);
  }

  // Cập nhật khoản chi
  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;

    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Xóa khoản chi
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;

    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Đóng database
  Future<void> close() async {
    final db = await instance.database;

    await db.close();
    _database = null;
  }
}