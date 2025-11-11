import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Centralized database manager for the app
/// Manages database initialization, schema creation, and migrations
class DatabaseManager {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 2;

  Database? _database;

  /// Initialize the database
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

    debugPrint('✅ [DatabaseManager] Database initialized (v$_databaseVersion)');
  }

  /// Get the database instance
  Future<Database> get database async {
    if (_database == null) {
      await init();
    }
    return _database!;
  }

  /// Create database schema for new installations
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('🔨 [DatabaseManager] Creating database schema v$version');

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
        confidence REAL NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense'
      )
    ''');
    debugPrint('  ✓ Created expenses table');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        nameEn TEXT NOT NULL,
        nameVi TEXT NOT NULL,
        keywordsEn TEXT NOT NULL,
        keywordsVi TEXT NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isSystem INTEGER NOT NULL,
        userId TEXT,
        type TEXT NOT NULL DEFAULT 'expense',
        createdAt TEXT NOT NULL
      )
    ''');
    debugPrint('  ✓ Created categories table');

    // Create recurring_templates table
    await db.execute('''
      CREATE TABLE recurring_templates (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        language TEXT NOT NULL,
        userId TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense',
        pattern TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        lastGeneratedDate TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');
    debugPrint('  ✓ Created recurring_templates table');

    debugPrint('✅ [DatabaseManager] Database schema created successfully');
  }

  /// Upgrade database schema for existing installations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 [DatabaseManager] Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Add recurring_templates table (v1 -> v2 migration)
      await db.execute('''
        CREATE TABLE recurring_templates (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          language TEXT NOT NULL,
          userId TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'expense',
          pattern TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          lastGeneratedDate TEXT,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
      debugPrint('  ✓ Added recurring_templates table');
    }

    debugPrint('✅ [DatabaseManager] Database upgraded successfully');
  }

  /// Close the database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
    debugPrint('🔒 [DatabaseManager] Database closed');
  }
}
