import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/category.dart' show QuickCategory;
import 'database_manager.dart';

/// Service for managing expenses using SQLite local database
class ExpenseService {
  static const String _tableName = 'expenses';
  static const String _categoriesTableName = 'categories';

  final DatabaseManager _databaseManager;
  Database? _database;

  ExpenseService(this._databaseManager);

  /// Initialize the expense service
  Future<void> init() async {
    _database = await _databaseManager.database;
    // Seed system categories if needed
    await _seedSystemCategories();
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
    debugPrint('   Type: ${expense.type.name}, Category: ${expense.categoryId}');
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

    debugPrint('📋 [ExpenseService] Loaded ${maps.length} expense(s)');
    return maps.map((map) => Expense.fromJson(map)).toList();
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    await _ensureInitialized();
    debugPrint('📝 [ExpenseService] Updating expense: ${expense.id}');
    await _database!.update(
      _tableName,
      expense.toJson(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    debugPrint('✅ [ExpenseService] Expense updated');
  }

  /// Delete an expense by ID
  Future<void> deleteExpense(String id) async {
    await _ensureInitialized();
    debugPrint('🗑️ [ExpenseService] Deleting expense: $id');
    await _database!.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('✅ [ExpenseService] Expense deleted');
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

  /// Get transactions by date range and type
  Future<List<Expense>> getTransactionsByDateRangeAndType(
    String userId,
    DateTime startDate,
    DateTime endDate,
    String type,
  ) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'userId = ? AND date >= ? AND date <= ? AND type = ?',
      whereArgs: [
        userId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        type,
      ],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromJson(map)).toList();
  }

  /// Get expense count for a user
  Future<int> getExpenseCount(String userId) async {
    await _ensureInitialized();
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE userId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total amount for a user
  Future<double> getTotalAmount(String userId) async {
    await _ensureInitialized();
    final result = await _database!.rawQuery(
      'SELECT SUM(amount) as total FROM $_tableName WHERE userId = ? AND type = ?',
      [userId, 'expense'],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Category management methods

  /// Save a category
  Future<void> saveCategory(QuickCategory category) async {
    await _ensureInitialized();
    debugPrint('💾 [ExpenseService] Saving category: ${category.nameEn}');
    await _database!.insert(
      _categoriesTableName,
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [ExpenseService] Category saved');
  }

  /// Get all categories for a user
  Future<List<QuickCategory>> getAllCategories(String? userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: userId != null ? 'userId = ? OR userId IS NULL' : 'userId IS NULL',
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'isSystem DESC, nameEn ASC',
    );

    return maps.map((map) => QuickCategory.fromJson(map)).toList();
  }

  /// Get a category by ID
  Future<QuickCategory?> getCategoryById(String id) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return QuickCategory.fromJson(maps.first);
  }

  /// Update a category
  Future<void> updateCategory(QuickCategory category) async {
    await _ensureInitialized();
    debugPrint('📝 [ExpenseService] Updating category: ${category.id}');
    await _database!.update(
      _categoriesTableName,
      category.toJson(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    debugPrint('✅ [ExpenseService] Category updated');
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    await _ensureInitialized();
    debugPrint('🗑️ [ExpenseService] Deleting category: $id');
    await _database!.delete(
      _categoriesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('✅ [ExpenseService] Category deleted');
  }

  /// Reassign expenses from one category to another
  Future<void> reassignExpenses(String fromCategoryId, String toCategoryId) async {
    await _ensureInitialized();
    debugPrint('🔄 [ExpenseService] Reassigning expenses from $fromCategoryId to $toCategoryId');
    await _database!.rawUpdate(
      'UPDATE $_tableName SET categoryId = ? WHERE categoryId = ?',
      [toCategoryId, fromCategoryId],
    );
    debugPrint('✅ [ExpenseService] Expenses reassigned');
  }

  /// Seed system categories
  Future<void> _seedSystemCategories() async {
    final categories = await getAllCategories(null);
    if (categories.isNotEmpty) {
      debugPrint('ℹ️ [ExpenseService] System categories already seeded');
      return;
    }

    debugPrint('🌱 [ExpenseService] Seeding system categories...');
    final systemCategories = QuickCategory.getDefaultSystemCategories();
    for (final category in systemCategories) {
      await saveCategory(category);
    }
    debugPrint('✅ [ExpenseService] System categories seeded');
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _database!.delete(_tableName);
    await _database!.delete(_categoriesTableName);
  }
}
