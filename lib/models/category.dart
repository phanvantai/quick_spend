import 'package:flutter/material.dart';
import 'dart:convert';
import 'expense.dart';

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
  final TransactionType type; // income or expense
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
    required this.type,
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

  /// Check if this is an income category
  bool get isIncomeCategory => type == TransactionType.income;

  /// Check if this is an expense category
  bool get isExpenseCategory => type == TransactionType.expense;

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
      'type': type.toJson(),
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
      type: json['type'] != null
          ? TransactionType.fromJson(json['type'] as String)
          : TransactionType.expense, // Default to expense for backward compatibility
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
        colorValue: Colors.orange.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
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
        colorValue: Colors.blue.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
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
        colorValue: Colors.purple.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
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
        colorValue: Colors.red.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
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
        colorValue: Colors.green.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
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
        colorValue: Colors.pink.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other',
        nameEn: 'Other',
        nameVi: 'Khác',
        keywordsEn: ['other', 'misc', 'miscellaneous'],
        keywordsVi: ['khác'],
        iconCodePoint: Icons.more_horiz.codePoint,
        colorValue: Colors.grey.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      // ====== Income Categories ======
      QuickCategory(
        id: 'salary',
        nameEn: 'Salary',
        nameVi: 'Lương',
        keywordsEn: [
          'salary',
          'wage',
          'paycheck',
          'income',
          'payment',
          'pay',
          'work',
          'job',
          'earnings',
        ],
        keywordsVi: [
          'lương',
          'tiền lương',
          'công',
          'lương tháng',
          'thu nhập',
          'trả lương',
          'nhận lương',
        ],
        iconCodePoint: Icons.account_balance_wallet.codePoint,
        colorValue: const Color(0xFF4CAF50).value, // Green
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'freelance',
        nameEn: 'Freelance',
        nameVi: 'Làm thêm',
        keywordsEn: [
          'freelance',
          'side job',
          'side hustle',
          'gig',
          'project',
          'contract',
          'part time',
          'extra income',
        ],
        keywordsVi: [
          'làm thêm',
          'freelance',
          'tự do',
          'dự án',
          'hợp đồng',
          'part time',
          'làm ngoài',
          'thu nhập phụ',
        ],
        iconCodePoint: Icons.laptop_mac.codePoint,
        colorValue: const Color(0xFF2196F3).value, // Blue
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'investment',
        nameEn: 'Investment',
        nameVi: 'Đầu tư',
        keywordsEn: [
          'investment',
          'dividend',
          'interest',
          'stock',
          'profit',
          'return',
          'capital gain',
          'bond',
          'crypto',
        ],
        keywordsVi: [
          'đầu tư',
          'cổ tức',
          'lãi',
          'cổ phiếu',
          'lợi nhuận',
          'sinh lời',
          'chứng khoán',
          'tiền lãi',
        ],
        iconCodePoint: Icons.trending_up.codePoint,
        colorValue: const Color(0xFF009688).value, // Teal
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'gift_received',
        nameEn: 'Gift',
        nameVi: 'Quà tặng',
        keywordsEn: [
          'gift',
          'present',
          'lucky money',
          'bonus',
          'reward',
          'prize',
          'red envelope',
          'allowance',
        ],
        keywordsVi: [
          'quà',
          'quà tặng',
          'lì xì',
          'tiền mừng',
          'thưởng',
          'giải thưởng',
          'phần thưởng',
          'tiền lì xì',
        ],
        iconCodePoint: Icons.card_giftcard.codePoint,
        colorValue: const Color(0xFFE91E63).value, // Pink
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'refund',
        nameEn: 'Refund',
        nameVi: 'Hoàn tiền',
        keywordsEn: [
          'refund',
          'return',
          'reimbursement',
          'cashback',
          'payback',
          'repayment',
        ],
        keywordsVi: [
          'hoàn tiền',
          'hoàn lại',
          'trả lại',
          'cashback',
          'hoàn',
        ],
        iconCodePoint: Icons.undo.codePoint,
        colorValue: const Color(0xFFFF9800).value, // Orange
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other_income',
        nameEn: 'Other Income',
        nameVi: 'Thu nhập khác',
        keywordsEn: [
          'other income',
          'miscellaneous income',
          'extra',
        ],
        keywordsVi: [
          'thu nhập khác',
          'thu khác',
        ],
        iconCodePoint: Icons.add_circle_outline.codePoint,
        colorValue: const Color(0xFF9C27B0).value, // Purple
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
    ];
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
