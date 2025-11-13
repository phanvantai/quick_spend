import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Centralized database manager for the app
/// Manages database initialization, schema creation, and migrations
class DatabaseManager {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 3;

  Database? _database;
  String? _migrationLanguage;

  /// Initialize the database
  /// [language] is used for migrating existing category data to single language
  Future<void> init({String? language}) async {
    if (_database != null) return;

    _migrationLanguage = language;

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

    // Create categories table (v3 schema with single language)
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        keywords TEXT NOT NULL,
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

    if (oldVersion < 3) {
      // Migrate categories to single language schema (v2 -> v3 migration)
      debugPrint('📦 [DatabaseManager] Migrating categories to single language schema...');

      // Determine which language to use based on user preference
      final useVietnamese = _migrationLanguage == 'vi';
      final nameColumn = useVietnamese ? 'nameVi' : 'nameEn';
      final keywordsColumn = useVietnamese ? 'keywordsVi' : 'keywordsEn';

      debugPrint('   Using language: ${useVietnamese ? "Vietnamese" : "English"}');

      // SQLite doesn't support DROP COLUMN, so we need to recreate the table
      await db.execute('''
        CREATE TABLE categories_new (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          keywords TEXT NOT NULL,
          iconCodePoint INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isSystem INTEGER NOT NULL,
          userId TEXT,
          type TEXT NOT NULL DEFAULT 'expense',
          createdAt TEXT NOT NULL
        )
      ''');

      // Check if type column exists in old table (added in later versions)
      final tableInfo = await db.rawQuery('PRAGMA table_info(categories)');
      final hasTypeColumn = tableInfo.any((col) => col['name'] == 'type');

      // Copy data with selected language
      if (hasTypeColumn) {
        // Old table has type column, copy it
        await db.execute('''
          INSERT INTO categories_new
            (id, name, keywords, iconCodePoint, colorValue, isSystem, userId, type, createdAt)
          SELECT
            id, $nameColumn, $keywordsColumn, iconCodePoint, colorValue, isSystem, userId, type, createdAt
          FROM categories
        ''');
      } else {
        // Old table doesn't have type column, use default 'expense'
        debugPrint('   Old table missing type column, using default "expense"');
        await db.execute('''
          INSERT INTO categories_new
            (id, name, keywords, iconCodePoint, colorValue, isSystem, userId, type, createdAt)
          SELECT
            id, $nameColumn, $keywordsColumn, iconCodePoint, colorValue, isSystem, userId, 'expense', createdAt
          FROM categories
        ''');
      }

      // Drop old table and rename new one
      await db.execute('DROP TABLE categories');
      await db.execute('ALTER TABLE categories_new RENAME TO categories');

      debugPrint('✅ [DatabaseManager] Categories migrated successfully');
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
