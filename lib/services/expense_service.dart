import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';

/// Service for managing expenses using SQLite local database
class ExpenseService {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 2; // Updated for categoryId migration
  static const String _tableName = 'expenses';
  static const String _categoriesTableName = 'categories';

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
      onUpgrade: _onUpgrade,
    );

    // Seed system categories if needed
    await _seedSystemCategories();
  }

  /// Create the database schema
  Future<void> _onCreate(Database db, int version) async {
    // Create expenses table with categoryId
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        language TEXT NOT NULL,
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
        rawInput TEXT NOT NULL,
        confidence REAL NOT NULL
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE $_categoriesTableName (
        id TEXT PRIMARY KEY,
        nameEn TEXT NOT NULL,
        nameVi TEXT NOT NULL,
        keywordsEn TEXT NOT NULL,
        keywordsVi TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isSystem INTEGER NOT NULL,
        userId TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    debugPrint('✅ [ExpenseService] Database schema created (v$version)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 [ExpenseService] Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Create categories table
      await db.execute('''
        CREATE TABLE $_categoriesTableName (
          id TEXT PRIMARY KEY,
          nameEn TEXT NOT NULL,
          nameVi TEXT NOT NULL,
          keywordsEn TEXT NOT NULL,
          keywordsVi TEXT NOT NULL,
          iconCodePoint INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isSystem INTEGER NOT NULL,
          userId TEXT,
          createdAt TEXT NOT NULL
        )
      ''');

      // Check if category column exists (old schema)
      final tableInfo = await db.rawQuery("PRAGMA table_info($_tableName)");
      final hasOldCategory = tableInfo.any((col) => col['name'] == 'category');

      if (hasOldCategory) {
        // Rename old category column to categoryId
        // SQLite doesn't support column rename directly, so we need to recreate table
        await db.execute('ALTER TABLE $_tableName RENAME TO ${_tableName}_old');

        // Create new table with categoryId
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            categoryId TEXT NOT NULL,
            language TEXT NOT NULL,
            date TEXT NOT NULL,
            userId TEXT NOT NULL,
            rawInput TEXT NOT NULL,
            confidence REAL NOT NULL
          )
        ''');

        // Copy data from old table, renaming category to categoryId
        await db.execute('''
          INSERT INTO $_tableName (id, amount, description, categoryId, language, date, userId, rawInput, confidence)
          SELECT id, amount, description, category, language, date, userId, rawInput, confidence
          FROM ${_tableName}_old
        ''');

        // Drop old table
        await db.execute('DROP TABLE ${_tableName}_old');
      } else {
        // Table already has categoryId, just add it if missing
        try {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN categoryId TEXT DEFAULT "other"');
        } catch (e) {
          // Column might already exist
          debugPrint('⚠️ [ExpenseService] categoryId column may already exist: $e');
        }
      }

      debugPrint('✅ [ExpenseService] Database upgraded successfully');
    }
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

  // ============================================================================
  // Category Management Methods
  // ============================================================================

  /// Seed system categories (predefined categories)
  Future<void> _seedSystemCategories() async {
    await _ensureInitialized();

    // Check if system categories already exist
    final count = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_categoriesTableName WHERE isSystem = 1',
    );
    final systemCount = Sqflite.firstIntValue(count) ?? 0;

    if (systemCount > 0) {
      debugPrint('✅ [ExpenseService] System categories already exist ($systemCount)');
      return;
    }

    debugPrint('🌱 [ExpenseService] Seeding system categories...');

    final systemCategories = Category.getDefaultSystemCategories();
    for (final category in systemCategories) {
      await _database!.insert(_categoriesTableName, category.toJson());
    }

    debugPrint('✅ [ExpenseService] Seeded ${systemCategories.length} system categories');
  }

  /// Get all categories for a user (system + user-defined)
  Future<List<Category>> getAllCategories(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: 'isSystem = 1 OR userId = ?',
      whereArgs: [userId],
      orderBy: 'isSystem DESC, createdAt ASC', // System categories first
    );

    return maps.map((map) => Category.fromJson(map)).toList();
  }

  /// Get only system categories
  Future<List<Category>> getSystemCategories() async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: 'isSystem = 1',
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => Category.fromJson(map)).toList();
  }

  /// Get only user-defined categories
  Future<List<Category>> getUserCategories(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: 'isSystem = 0 AND userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => Category.fromJson(map)).toList();
  }

  /// Get category by ID
  Future<Category?> getCategoryById(String id) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _categoriesTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Category.fromJson(maps.first);
  }

  /// Create a new user-defined category
  Future<void> createCategory(Category category) async {
    await _ensureInitialized();

    if (category.isSystem) {
      throw Exception('Cannot create system categories via this method');
    }

    debugPrint('💾 [ExpenseService] Creating user category: ${category.nameEn}');
    await _database!.insert(
      _categoriesTableName,
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [ExpenseService] Category created');
  }

  /// Update a user-defined category
  Future<void> updateCategory(Category category) async {
    await _ensureInitialized();

    if (category.isSystem) {
      throw Exception('Cannot update system categories');
    }

    await _database!.update(
      _categoriesTableName,
      category.toJson(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Delete a user-defined category
  Future<void> deleteCategory(String id) async {
    await _ensureInitialized();

    // Ensure it's not a system category
    final category = await getCategoryById(id);
    if (category?.isSystem == true) {
      throw Exception('Cannot delete system categories');
    }

    await _database!.delete(
      _categoriesTableName,
      where: 'id = ? AND isSystem = 0',
      whereArgs: [id],
    );
  }

  /// Clear all user-defined categories (for testing)
  Future<void> clearUserCategories(String userId) async {
    await _ensureInitialized();
    await _database!.delete(
      _categoriesTableName,
      where: 'isSystem = 0 AND userId = ?',
      whereArgs: [userId],
    );
  }
}
