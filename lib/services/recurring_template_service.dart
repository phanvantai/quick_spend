import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recurring_expense_template.dart';

/// Service for managing recurring expense templates using SQLite
class RecurringTemplateService {
  static const String _databaseName = 'quick_spend.db';
  static const int _databaseVersion = 2; // v2 adds recurring_templates table
  static const String _tableName = 'recurring_templates';

  Database? _database;

  /// Initialize the service
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
  }

  /// Create the database schema
  Future<void> _onCreate(Database db, int version) async {
    // Create recurring_templates table
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        language TEXT NOT NULL,
        userId TEXT NOT NULL,
        type TEXT NOT NULL,
        pattern TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        lastGeneratedDate TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    debugPrint('✅ [RecurringTemplateService] Database schema created (v$version)');
  }

  /// Upgrade the database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 [RecurringTemplateService] Upgrading database from v$oldVersion to v$newVersion');

    // Migrate from version 1 to version 2 (add recurring_templates table)
    if (oldVersion < 2) {
      debugPrint('   Creating recurring_templates table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          language TEXT NOT NULL,
          userId TEXT NOT NULL,
          type TEXT NOT NULL,
          pattern TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          lastGeneratedDate TEXT,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
      debugPrint('✅ [RecurringTemplateService] recurring_templates table created');
    }

    debugPrint('✅ [RecurringTemplateService] Database upgraded to v$newVersion');
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (_database == null) {
      await init();
    }
  }

  /// Save a new recurring template
  Future<void> saveTemplate(RecurringExpenseTemplate template) async {
    await _ensureInitialized();
    debugPrint('💾 [RecurringTemplateService] Saving template: ${template.description}');
    await _database!.insert(
      _tableName,
      template.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [RecurringTemplateService] Template saved');
  }

  /// Get all templates for a user
  Future<List<RecurringExpenseTemplate>> getAllTemplates(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'description ASC',
    );

    debugPrint('📋 [RecurringTemplateService] Loaded ${maps.length} template(s)');
    return maps.map((map) => RecurringExpenseTemplate.fromJson(map)).toList();
  }

  /// Get only active templates for a user
  Future<List<RecurringExpenseTemplate>> getActiveTemplates(String userId) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'userId = ? AND isActive = 1',
      whereArgs: [userId],
      orderBy: 'description ASC',
    );

    return maps.map((map) => RecurringExpenseTemplate.fromJson(map)).toList();
  }

  /// Get a single template by ID
  Future<RecurringExpenseTemplate?> getTemplateById(String id) async {
    await _ensureInitialized();

    final List<Map<String, dynamic>> maps = await _database!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return RecurringExpenseTemplate.fromJson(maps.first);
  }

  /// Update an existing template
  Future<void> updateTemplate(RecurringExpenseTemplate template) async {
    await _ensureInitialized();
    debugPrint('📝 [RecurringTemplateService] Updating template: ${template.id}');
    await _database!.update(
      _tableName,
      template.toJson(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
    debugPrint('✅ [RecurringTemplateService] Template updated');
  }

  /// Update the last generated date for a template
  Future<void> updateLastGeneratedDate(String templateId, DateTime date) async {
    await _ensureInitialized();

    await _database!.rawUpdate(
      'UPDATE $_tableName SET lastGeneratedDate = ? WHERE id = ?',
      [date.toIso8601String(), templateId],
    );
    debugPrint('✅ [RecurringTemplateService] Updated lastGeneratedDate for template $templateId');
  }

  /// Toggle template active status
  Future<void> toggleActive(String templateId, bool isActive) async {
    await _ensureInitialized();

    await _database!.rawUpdate(
      'UPDATE $_tableName SET isActive = ? WHERE id = ?',
      [isActive ? 1 : 0, templateId],
    );
    debugPrint('✅ [RecurringTemplateService] Toggled active status for template $templateId to $isActive');
  }

  /// Delete a template by ID
  Future<void> deleteTemplate(String id) async {
    await _ensureInitialized();
    debugPrint('🗑️ [RecurringTemplateService] Deleting template: $id');
    await _database!.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('✅ [RecurringTemplateService] Template deleted');
  }

  /// Delete all templates for a user
  Future<void> deleteAllTemplates(String userId) async {
    await _ensureInitialized();
    await _database!.delete(
      _tableName,
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  /// Get template count for a user
  Future<int> getTemplateCount(String userId) async {
    await _ensureInitialized();
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE userId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _database!.delete(_tableName);
  }
}
