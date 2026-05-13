import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static Database? _db;
  static const String _dbName = 'accounting.db';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT DEFAULT '',
            transactionDate TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            syncVersion INTEGER DEFAULT 1,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT DEFAULT '📦',
            type TEXT NOT NULL,
            sortOrder INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // ============ 账单本地 CRUD ============

  Future<int> insertTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    tx['createdAt'] = tx['createdAt'] ?? DateTime.now().toIso8601String();
    tx['updatedAt'] = tx['updatedAt'] ?? DateTime.now().toIso8601String();
    tx['synced'] = 0;
    return db.insert('transactions', tx, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await database;
    return db.query('transactions', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update('transactions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getLocalTransactions({
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (type != null) {
      where = 'type = ?';
      whereArgs = [type];
    }
    return db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transactionDate DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ============ 分类本地缓存 ============

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    final db = await database;
    await db.delete('categories');
    for (final c in categories) {
      await db.insert('categories', {
        'id': c['id'],
        'name': c['name'],
        'icon': c['icon'],
        'type': c['type'],
        'sortOrder': c['sortOrder'] ?? 0,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'sortOrder ASC');
  }

  // ============ 月度统计（本地） ============

  Future<Map<String, double>> getLocalMonthlyStats(int year, int month) async {
    final db = await database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final end = year == DateTime.now().year && month == DateTime.now().month
        ? DateTime.now().toIso8601String().split('T')[0]
        : '$year-${month.toString().padLeft(2, '0')}-31';

    final result = await db.rawQuery('''
      SELECT type, SUM(amount) as total FROM transactions
      WHERE transactionDate >= ? AND transactionDate <= ?
      GROUP BY type
    ''', [start, end]);

    double income = 0, expense = 0;
    for (final row in result) {
      if (row['type'] == 'income') income = (row['total'] as num).toDouble();
      else expense = (row['total'] as num).toDouble();
    }
    return {'income': income, 'expense': expense};
  }
}
