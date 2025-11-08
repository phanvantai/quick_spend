import 'package:flutter/material.dart';
import 'dart:convert';

/// Legacy enum for backward compatibility during migration
/// Will be deprecated once migration is complete
enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  other,
}

/// Category model with support for both system and user-defined categories
class QuickCategory {
  final String id;
  final String nameEn;
  final String nameVi;
  final List<String> keywordsEn;
  final List<String> keywordsVi;
  final int iconCodePoint; // Store icon as code point
  final int colorValue; // Store color as integer
  final bool isSystem; // true for system categories, false for user-defined
  final String? userId; // null for system categories
  final DateTime createdAt;

  const QuickCategory({
    required this.id,
    required this.nameEn,
    required this.nameVi,
    required this.keywordsEn,
    required this.keywordsVi,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isSystem,
    this.userId,
    required this.createdAt,
  });

  /// Get label based on language
  String getLabel(String language) {
    return language == 'vi' ? nameVi : nameEn;
  }

  /// Get keywords based on language
  List<String> getKeywords(String language) {
    return language == 'vi' ? keywordsVi : keywordsEn;
  }

  /// Get icon from code point
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  /// Get color from value
  Color get color => Color(colorValue);

  /// Convert Category to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameVi': nameVi,
      'keywordsEn': jsonEncode(keywordsEn),
      'keywordsVi': jsonEncode(keywordsVi),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isSystem': isSystem ? 1 : 0,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create Category from JSON
  factory QuickCategory.fromJson(Map<String, dynamic> json) {
    return QuickCategory(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameVi: json['nameVi'] as String,
      keywordsEn: (jsonDecode(json['keywordsEn'] as String) as List)
          .map((e) => e.toString())
          .toList(),
      keywordsVi: (jsonDecode(json['keywordsVi'] as String) as List)
          .map((e) => e.toString())
          .toList(),
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      isSystem: (json['isSystem'] as int) == 1,
      userId: json['userId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Get default system categories (for seeding database)
  static List<QuickCategory> getDefaultSystemCategories() {
    final now = DateTime.now();

    return [
      QuickCategory(
        id: 'food',
        nameEn: 'Food',
        nameVi: 'Ăn uống',
        keywordsEn: [
          'food',
          'eat',
          'lunch',
          'dinner',
          'breakfast',
          'coffee',
          'drink',
          'restaurant',
          'cafe',
          'pizza',
          'burger',
          'snack',
          'meal',
          'groceries',
        ],
        keywordsVi: [
          'ăn',
          'cơm',
          'phở',
          'bún',
          'cà phê',
          'cafe',
          'trà',
          'nước',
          'uống',
          'sáng',
          'trưa',
          'tối',
          'quán',
          'nhà hàng',
          'ăn vặt',
          'đồ ăn',
          'thức ăn',
          'rau',
          'thịt',
          'cá',
        ],
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: Colors.orange.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'transport',
        nameEn: 'Transport',
        nameVi: 'Di chuyển',
        keywordsEn: [
          'transport',
          'taxi',
          'uber',
          'grab',
          'bus',
          'train',
          'metro',
          'parking',
          'gas',
          'petrol',
          'fuel',
          'car',
          'bike',
          'motorbike',
          'toll',
        ],
        keywordsVi: [
          'xe',
          'taxi',
          'grab',
          'xăng',
          'dầu',
          'bus',
          'xe buýt',
          'tàu',
          'metro',
          'đỗ xe',
          'gửi xe',
          'ô tô',
          'xe máy',
          'phí',
          'cầu đường',
          'di chuyển',
        ],
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: Colors.blue.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'shopping',
        nameEn: 'Shopping',
        nameVi: 'Mua sắm',
        keywordsEn: [
          'shopping',
          'shop',
          'buy',
          'clothes',
          'shoes',
          'mall',
          'store',
          'gift',
          'book',
          'electronics',
          'purchase',
        ],
        keywordsVi: [
          'mua',
          'shopping',
          'quần áo',
          'giày',
          'dép',
          'áo',
          'váy',
          'đồ',
          'siêu thị',
          'chợ',
          'quà',
          'tặng',
          'sách',
          'điện thoại',
          'máy tính',
        ],
        iconCodePoint: Icons.shopping_bag.codePoint,
        colorValue: Colors.purple.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'bills',
        nameEn: 'Bills',
        nameVi: 'Hóa đơn',
        keywordsEn: [
          'bill',
          'rent',
          'electricity',
          'water',
          'internet',
          'phone',
          'utility',
          'insurance',
          'subscription',
        ],
        keywordsVi: [
          'hóa đơn',
          'tiền nhà',
          'điện',
          'nước',
          'internet',
          'wifi',
          'điện thoại',
          'bảo hiểm',
          'thuê',
          'phí',
        ],
        iconCodePoint: Icons.receipt_long.codePoint,
        colorValue: Colors.red.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'health',
        nameEn: 'Health',
        nameVi: 'Sức khỏe',
        keywordsEn: [
          'health',
          'medicine',
          'doctor',
          'hospital',
          'pharmacy',
          'drug',
          'clinic',
          'medical',
          'gym',
          'fitness',
        ],
        keywordsVi: [
          'thuốc',
          'bác sĩ',
          'bệnh viện',
          'khám',
          'y tế',
          'sức khỏe',
          'nhà thuốc',
          'phòng khám',
          'gym',
          'thể dục',
        ],
        iconCodePoint: Icons.local_hospital.codePoint,
        colorValue: Colors.green.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'entertainment',
        nameEn: 'Entertainment',
        nameVi: 'Giải trí',
        keywordsEn: [
          'entertainment',
          'movie',
          'cinema',
          'game',
          'music',
          'concert',
          'party',
          'fun',
          'hobby',
          'sport',
        ],
        keywordsVi: [
          'giải trí',
          'phim',
          'rạp',
          'cinema',
          'game',
          'nhạc',
          'ca nhạc',
          'tiệc',
          'vui chơi',
          'thể thao',
          'bóng đá',
        ],
        iconCodePoint: Icons.movie.codePoint,
        colorValue: Colors.pink.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other',
        nameEn: 'Other',
        nameVi: 'Khác',
        keywordsEn: ['other', 'misc', 'miscellaneous'],
        keywordsVi: ['khác'],
        iconCodePoint: Icons.more_horiz.codePoint,
        colorValue: Colors.grey.value,
        isSystem: true,
        userId: null,
        createdAt: now,
      ),
    ];
  }

  /// Legacy: Get category by enum type (for backward compatibility)
  /// @deprecated Use getCategoryById instead
  static QuickCategory getByType(ExpenseCategory type) {
    // Map enum to system category IDs
    final systemCategories = getDefaultSystemCategories();
    final id = type.toString().split('.').last;
    return systemCategories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => systemCategories.last, // Return 'other'
    );
  }

  /// Legacy: Get all categories (for backward compatibility)
  /// @deprecated Use CategoryService.getAllCategories() instead
  static List<QuickCategory> getAllCategories() {
    return getDefaultSystemCategories();
  }

  /// Copy with method for creating modified copies
  QuickCategory copyWith({
    String? id,
    String? nameEn,
    String? nameVi,
    List<String>? keywordsEn,
    List<String>? keywordsVi,
    int? iconCodePoint,
    int? colorValue,
    bool? isSystem,
    String? userId,
    DateTime? createdAt,
  }) {
    return QuickCategory(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameVi: nameVi ?? this.nameVi,
      keywordsEn: keywordsEn ?? this.keywordsEn,
      keywordsVi: keywordsVi ?? this.keywordsVi,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isSystem: isSystem ?? this.isSystem,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
