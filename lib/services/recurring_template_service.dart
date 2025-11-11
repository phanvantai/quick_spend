import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/recurring_expense_template.dart';
import 'database_manager.dart';

/// Service for managing recurring expense templates using SQLite
/// Uses the shared database from DatabaseManager
class RecurringTemplateService {
  static const String _tableName = 'recurring_templates';

  final DatabaseManager _databaseManager;
  Database? _database;

  RecurringTemplateService(this._databaseManager);

  /// Initialize the service
  Future<void> init() async {
    _database = await _databaseManager.database;
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

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _database!.delete(_tableName);
  }
}
