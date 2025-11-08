import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';

/// Service for managing expense categories (both system and user-defined)
class CategoryService {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 2; // Incremented for category table
  static const String _tableName = 'categories';

  Database? _database;

  /// Initialize the category service
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
    // Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
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
      CREATE TABLE $_tableName (
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

    debugPrint('✅ [CategoryService] Database schema created');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      debugPrint('🔄 [CategoryService] Upgrading database from v$oldVersion to v$newVersion');

      // Create categories table
      await db.execute('''
        CREATE TABLE $_tableName (
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

      // Add categoryId column to expenses table
      await db.execute('ALTER TABLE expenses ADD COLUMN categoryId TEXT');

      // Migrate existing expenses to use category IDs
      // Old enum values will be mapped to system category IDs
      await db.execute("UPDATE expenses SET categoryId = 'food' WHERE category = 'food'");
      await db.execute("UPDATE expenses SET categoryId = 'transport' WHERE category = 'transport'");
      await db.execute("UPDATE expenses SET categoryId = 'shopping' WHERE category = 'shopping'");
      await db.execute("UPDATE expenses SET categoryId = 'bills' WHERE category = 'bills'");
      await db.execute("UPDATE expenses SET categoryId = 'health' WHERE category = 'health'");
      await db.execute("UPDATE expenses SET categoryId = 'entertainment' WHERE category = 'entertainment'");
      await db.execute("UPDATE expenses SET categoryId = 'other' WHERE category = 'other'");

      debugPrint('✅ [CategoryService] Database upgraded successfully');
    }
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (_database == null) {
      await init();
    }
  }

  /// Seed system categories (predefined categories)
  Future<void> _seedSystemCategories() async {
    await _ensureInitialized();

    // Check if system categories already exist
    final count = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE isSystem = 1',
    );
    final systemCount = Sqflite.firstIntValue(count) ?? 0;

    if (systemCount > 0) {
      debugPrint('✅ [CategoryService] System categories already exist ($systemCount)');
      return;
    }

    debugPrint('🌱 [CategoryService] Seeding system categories...');

    final systemCategories = Category.getDefaultSystemCategories();
    for (final category in systemCategories) {
      await _database!.insert(_tableName, category.toJson());
    }

    debugPrint('✅ [CategoryService] Seeded ${systemCategories.length} system categories');
  }

  /// Get all categories for a user (system + user-defined)
  Future<List<Category>> getAllCategories(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
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
      _tableName,
      where: 'isSystem = 1',
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => Category.fromJson(map)).toList();
  }

  /// Get only user-defined categories
  Future<List<Category>> getUserCategories(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
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
      _tableName,
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

    debugPrint('💾 [CategoryService] Creating user category: ${category.nameEn}');
    await _database!.insert(
      _tableName,
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [CategoryService] Category created');
  }

  /// Update a user-defined category
  Future<void> updateCategory(Category category) async {
    await _ensureInitialized();

    if (category.isSystem) {
      throw Exception('Cannot update system categories');
    }

    await _database!.update(
      _tableName,
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
      _tableName,
      where: 'id = ? AND isSystem = 0',
      whereArgs: [id],
    );
  }

  /// Close the database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Clear all user-defined categories (for testing)
  Future<void> clearUserCategories(String userId) async {
    await _ensureInitialized();
    await _database!.delete(
      _tableName,
      where: 'isSystem = 0 AND userId = ?',
      whereArgs: [userId],
    );
  }
}
