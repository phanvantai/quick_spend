import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../services/expense_service.dart';

/// Provider for managing categories (system and user-defined)
class CategoryProvider extends ChangeNotifier {
  final ExpenseService _expenseService;
  List<Category> _categories = [];
  bool _isLoading = true;
  String _currentUserId = 'local_user';

  CategoryProvider(this._expenseService) {
    _loadCategories();
  }

  /// Current list of categories (system + user-defined)
  List<Category> get categories => _categories;

  /// Whether categories are loading
  bool get isLoading => _isLoading;

  /// Get only system categories
  List<Category> get systemCategories =>
      _categories.where((cat) => cat.isSystem).toList();

  /// Get only user-defined categories
  List<Category> get userCategories =>
      _categories.where((cat) => !cat.isSystem).toList();

  /// Set the current user ID
  void setUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadCategories();
    }
  }

  /// Load all categories for the current user
  Future<void> _loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _expenseService.getAllCategories(_currentUserId);
      debugPrint('📂 [CategoryProvider] Loaded ${_categories.length} categories');
    } catch (e) {
      debugPrint('❌ [CategoryProvider] Error loading categories: $e');
      _categories = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload categories from database
  Future<void> refresh() async {
    await _loadCategories();
  }

  /// Get category by ID
  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new user-defined category
  Future<void> createCategory(Category category) async {
    try {
      await _expenseService.createCategory(category);
      _categories.add(category);
      notifyListeners();
      debugPrint('✅ [CategoryProvider] Created category: ${category.nameEn}');
    } catch (e) {
      debugPrint('❌ [CategoryProvider] Error creating category: $e');
      rethrow;
    }
  }

  /// Update a user-defined category
  Future<void> updateCategory(Category category) async {
    try {
      await _expenseService.updateCategory(category);
      final index = _categories.indexWhere((cat) => cat.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        notifyListeners();
      }
      debugPrint('✅ [CategoryProvider] Updated category: ${category.nameEn}');
    } catch (e) {
      debugPrint('❌ [CategoryProvider] Error updating category: $e');
      rethrow;
    }
  }

  /// Delete a user-defined category
  Future<void> deleteCategory(String id) async {
    try {
      await _expenseService.deleteCategory(id);
      _categories.removeWhere((cat) => cat.id == id);
      notifyListeners();
      debugPrint('✅ [CategoryProvider] Deleted category: $id');
    } catch (e) {
      debugPrint('❌ [CategoryProvider] Error deleting category: $e');
      rethrow;
    }
  }

  /// Check if a category ID exists
  bool categoryExists(String id) {
    return _categories.any((cat) => cat.id == id);
  }
}
