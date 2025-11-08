import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

/// Service for managing expenses using SQLite local database
class ExpenseService {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'expenses';

  Database? _database;

  /// Initialize the expense service
  Future<void> init() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Create the database schema
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        language TEXT NOT NULL,
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
        rawInput TEXT NOT NULL,
        confidence REAL NOT NULL
      )
    ''');
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (_database == null) {
      await init();
    }
  }

  /// Save a new expense
  Future<void> saveExpense(Expense expense) async {
    await _ensureInitialized();
    debugPrint('💾 [ExpenseService] Saving expense: ${expense.description} - ${expense.amount}');
    await _database!.insert(
      _tableName,
      expense.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [ExpenseService] Expense saved to SQLite');
  }

  /// Get all expenses for a user, ordered by date (newest first)
  Future<List<Expense>> getAllExpenses(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    debugPrint('📋 [ExpenseService] Loaded ${maps.length} expense(s) from SQLite');
    return maps.map((map) => Expense.fromJson(map)).toList();
  }

  /// Get expenses for a specific date range
  Future<List<Expense>> getExpensesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        userId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromJson(map)).toList();
  }

  /// Get a single expense by ID
  Future<Expense?> getExpenseById(String id) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Expense.fromJson(maps.first);
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    await _ensureInitialized();
    await _database!.update(
      _tableName,
      expense.toJson(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete an expense by ID
  Future<void> deleteExpense(String id) async {
    await _ensureInitialized();
    await _database!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all expenses for a user
  Future<void> deleteAllExpenses(String userId) async {
    await _ensureInitialized();
    await _database!.delete(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  /// Get total expenses count for a user
  Future<int> getExpenseCount(String userId) async {
    await _ensureInitialized();
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE userId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total amount spent for a user
  Future<double> getTotalAmount(String userId) async {
    await _ensureInitialized();
    final result = await _database!.rawQuery(
      'SELECT SUM(amount) as total FROM $_tableName WHERE userId = ?',
      [userId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Close the database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Clear all data (for testing/debugging)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _database!.delete(_tableName);
  }

  /// Migrate expenses with incorrect userIds to the correct one
  ///
  /// This fixes legacy data where expenses may have been created with
  /// different userId values (e.g., 'default_user' instead of 'local_user').
  Future<void> migrateUserIds(String correctUserId) async {
    await _ensureInitialized();

    // Get count of expenses with wrong userId
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE userId != ?',
      [correctUserId],
    );
    final wrongCount = Sqflite.firstIntValue(result) ?? 0;

    if (wrongCount > 0) {
      debugPrint(
        '🔄 [ExpenseService] Found $wrongCount expense(s) with incorrect userId, migrating...',
      );

      // Update all expenses to use the correct userId
      final updatedCount = await _database!.rawUpdate(
        'UPDATE $_tableName SET userId = ? WHERE userId != ?',
        [correctUserId, correctUserId],
      );

      debugPrint(
        '✅ [ExpenseService] Migrated $updatedCount expense(s) to userId: $correctUserId',
      );
    }
  }
}
