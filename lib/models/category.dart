import 'package:flutter/material.dart';
import 'dart:convert';
import 'expense.dart';

/// Category model with support for both system and user-defined categories
class QuickCategory {
  final String id;
  final String name;
  final List<String> keywords;
  final int iconCodePoint; // Store icon as code point
  final int colorValue; // Store color as integer
  final bool isSystem; // true for system categories, false for user-defined
  final String? userId; // null for system categories
  final TransactionType type; // income or expense
  final DateTime createdAt;

  const QuickCategory({
    required this.id,
    required this.name,
    required this.keywords,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isSystem,
    this.userId,
    required this.type,
    required this.createdAt,
  });

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
      'name': name,
      'keywords': jsonEncode(keywords),
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
      name: json['name'] as String,
      keywords: (jsonDecode(json['keywords'] as String) as List)
          .map((e) => e.toString())
          .toList(),
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      isSystem: (json['isSystem'] as int) == 1,
      userId: json['userId'] as String?,
      type: json['type'] != null
          ? TransactionType.fromJson(json['type'] as String)
          : TransactionType
                .expense, // Default to expense for backward compatibility
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Get default system categories (for seeding database)
  /// [language] should be 'en' or 'vi'
  static List<QuickCategory> getDefaultSystemCategories(String language) {
    final now = DateTime.now();
    final isVietnamese = language == 'vi';

    return [
      QuickCategory(
        id: 'food',
        name: isVietnamese ? 'Ăn uống' : 'Food',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: Colors.orange.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'transport',
        name: isVietnamese ? 'Di chuyển' : 'Transport',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: Colors.blue.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'shopping',
        name: isVietnamese ? 'Mua sắm' : 'Shopping',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.shopping_bag.codePoint,
        colorValue: Colors.purple.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'bills',
        name: isVietnamese ? 'Hóa đơn' : 'Bills',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.receipt_long.codePoint,
        colorValue: Colors.red.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'health',
        name: isVietnamese ? 'Sức khỏe' : 'Health',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.local_hospital.codePoint,
        colorValue: Colors.green.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'entertainment',
        name: isVietnamese ? 'Giải trí' : 'Entertainment',
        keywords: isVietnamese
            ? [
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
              ]
            : [
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
        iconCodePoint: Icons.movie.codePoint,
        colorValue: Colors.pink.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other',
        name: isVietnamese ? 'Khác' : 'Other',
        keywords: isVietnamese
            ? ['khác']
            : ['other', 'misc', 'miscellaneous'],
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
        name: isVietnamese ? 'Lương' : 'Salary',
        keywords: isVietnamese
            ? [
                'lương',
                'tiền lương',
                'công',
                'lương tháng',
                'thu nhập',
                'trả lương',
                'nhận lương',
              ]
            : [
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
        iconCodePoint: Icons.account_balance_wallet.codePoint,
        colorValue: const Color(0xFF4CAF50).toARGB32(), // Green
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'freelance',
        name: isVietnamese ? 'Làm thêm' : 'Freelance',
        keywords: isVietnamese
            ? [
                'làm thêm',
                'freelance',
                'tự do',
                'dự án',
                'hợp đồng',
                'part time',
                'làm ngoài',
                'thu nhập phụ',
              ]
            : [
                'freelance',
                'side job',
                'side hustle',
                'gig',
                'project',
                'contract',
                'part time',
                'extra income',
              ],
        iconCodePoint: Icons.laptop_mac.codePoint,
        colorValue: const Color(0xFF2196F3).toARGB32(), // Blue
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'investment',
        name: isVietnamese ? 'Đầu tư' : 'Investment',
        keywords: isVietnamese
            ? [
                'đầu tư',
                'cổ tức',
                'lãi',
                'cổ phiếu',
                'lợi nhuận',
                'sinh lời',
                'chứng khoán',
                'tiền lãi',
              ]
            : [
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
        iconCodePoint: Icons.trending_up.codePoint,
        colorValue: const Color(0xFF009688).toARGB32(), // Teal
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'gift_received',
        name: isVietnamese ? 'Quà tặng' : 'Gift',
        keywords: isVietnamese
            ? [
                'quà',
                'quà tặng',
                'lì xì',
                'tiền mừng',
                'thưởng',
                'giải thưởng',
                'phần thưởng',
                'tiền lì xì',
              ]
            : [
                'gift',
                'present',
                'lucky money',
                'bonus',
                'reward',
                'prize',
                'red envelope',
                'allowance',
              ],
        iconCodePoint: Icons.card_giftcard.codePoint,
        colorValue: const Color(0xFFE91E63).toARGB32(), // Pink
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'refund',
        name: isVietnamese ? 'Hoàn tiền' : 'Refund',
        keywords: isVietnamese
            ? ['hoàn tiền', 'hoàn lại', 'trả lại', 'cashback', 'hoàn']
            : [
                'refund',
                'return',
                'reimbursement',
                'cashback',
                'payback',
                'repayment',
              ],
        iconCodePoint: Icons.undo.codePoint,
        colorValue: const Color(0xFFFF9800).toARGB32(), // Orange
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other_income',
        name: isVietnamese ? 'Thu nhập khác' : 'Other Income',
        keywords: isVietnamese
            ? ['thu nhập khác', 'thu khác']
            : ['other income', 'miscellaneous income', 'extra'],
        iconCodePoint: Icons.add_circle_outline.codePoint,
        colorValue: const Color(0xFF9C27B0).toARGB32(), // Purple
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
    ];
  }

  /// Copy with method for creating modified copies
  QuickCategory copyWith({
    String? id,
    String? name,
    List<String>? keywords,
    int? iconCodePoint,
    int? colorValue,
    bool? isSystem,
    String? userId,
    TransactionType? type,
    DateTime? createdAt,
  }) {
    return QuickCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      keywords: keywords ?? this.keywords,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isSystem: isSystem ?? this.isSystem,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
