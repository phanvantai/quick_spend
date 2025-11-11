import 'package:flutter/foundation.dart';
import '../models/recurring_expense_template.dart';
import '../services/recurring_template_service.dart';
import '../utils/constants.dart';

/// Provider for managing recurring expense templates
class RecurringTemplateProvider extends ChangeNotifier {
  final RecurringTemplateService _templateService;
  List<RecurringExpenseTemplate> _templates = [];
  bool _isLoading = true;
  String _currentUserId = AppConstants.defaultUserId;

  RecurringTemplateProvider(this._templateService) {
    _loadTemplates();
  }

  /// Current list of templates
  List<RecurringExpenseTemplate> get templates => _templates;

  /// Whether the provider is loading
  bool get isLoading => _isLoading;

  /// Current user ID
  String get currentUserId => _currentUserId;

  /// Total number of templates
  int get templateCount => _templates.length;

  /// Number of active templates
  int get activeTemplateCount =>
      _templates.where((t) => t.isActive).length;

  /// Number of inactive templates
  int get inactiveTemplateCount =>
      _templates.where((t) => !t.isActive).length;

  /// List of active templates only
  List<RecurringExpenseTemplate> get activeTemplates =>
      _templates.where((t) => t.isActive).toList();

  /// List of inactive templates only
  List<RecurringExpenseTemplate> get inactiveTemplates =>
      _templates.where((t) => !t.isActive).toList();

  /// Set the current user ID
  void setUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadTemplates();
    }
  }

  /// Load templates from database
  Future<void> _loadTemplates() async {
    _isLoading = true;
    notifyListeners();

    try {
      _templates = await _templateService.getAllTemplates(_currentUserId);
      debugPrint('📋 [RecurringTemplateProvider] Loaded ${_templates.length} template(s)');
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error loading templates: $e');
      _templates = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload templates from database
  Future<void> refresh() async {
    await _loadTemplates();
  }

  /// Add a new template
  Future<void> addTemplate(RecurringExpenseTemplate template) async {
    try {
      debugPrint('➕ [RecurringTemplateProvider] Adding template: ${template.description}');
      await _templateService.saveTemplate(template);
      _templates.insert(0, template); // Add to beginning (newest first)
      debugPrint('✅ [RecurringTemplateProvider] Template added successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error adding template: $e');
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate(RecurringExpenseTemplate template) async {
    try {
      debugPrint('📝 [RecurringTemplateProvider] Updating template: ${template.id}');
      await _templateService.updateTemplate(template);
      final index = _templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _templates[index] = template;
        debugPrint('✅ [RecurringTemplateProvider] Template updated successfully');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error updating template: $e');
      rethrow;
    }
  }

  /// Toggle template active status
  Future<void> toggleActive(String templateId, bool isActive) async {
    try {
      debugPrint('🔄 [RecurringTemplateProvider] Toggling template $templateId to ${isActive ? "active" : "inactive"}');
      await _templateService.toggleActive(templateId, isActive);
      final index = _templates.indexWhere((t) => t.id == templateId);
      if (index != -1) {
        _templates[index] = _templates[index].copyWith(isActive: isActive);
        debugPrint('✅ [RecurringTemplateProvider] Template toggled successfully');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error toggling template: $e');
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    try {
      debugPrint('🗑️ [RecurringTemplateProvider] Deleting template: $templateId');
      await _templateService.deleteTemplate(templateId);
      _templates.removeWhere((t) => t.id == templateId);
      debugPrint('✅ [RecurringTemplateProvider] Template deleted successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error deleting template: $e');
      rethrow;
    }
  }

  /// Delete all templates for current user
  Future<void> deleteAllTemplates() async {
    try {
      debugPrint('🗑️ [RecurringTemplateProvider] Deleting all templates');
      await _templateService.deleteAllTemplates(_currentUserId);
      _templates.clear();
      debugPrint('✅ [RecurringTemplateProvider] All templates deleted');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [RecurringTemplateProvider] Error deleting all templates: $e');
      rethrow;
    }
  }

  /// Get a template by ID
  RecurringExpenseTemplate? getTemplateById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Reset all data (for testing)
  Future<void> reset() async {
    await _templateService.clearAll();
    await _loadTemplates();
  }
}
