import 'package:flutter/material.dart';

/// Enum representing expense categories
enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  other,
}

/// Category model with bilingual support and keyword lists
class Category {
  final ExpenseCategory type;
  final String labelEn;
  final String labelVi;
  final List<String> keywordsEn;
  final List<String> keywordsVi;
  final IconData icon;
  final Color color;

  const Category({
    required this.type,
    required this.labelEn,
    required this.labelVi,
    required this.keywordsEn,
    required this.keywordsVi,
    required this.icon,
    required this.color,
  });

  /// Get label based on language
  String getLabel(String language) {
    return language == 'vi' ? labelVi : labelEn;
  }

  /// Get keywords based on language
  List<String> getKeywords(String language) {
    return language == 'vi' ? keywordsVi : keywordsEn;
  }

  /// Static category definitions
  static final Map<ExpenseCategory, Category> categories = {
    ExpenseCategory.food: Category(
      type: ExpenseCategory.food,
      labelEn: 'Food',
      labelVi: 'Ăn uống',
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
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    ExpenseCategory.transport: Category(
      type: ExpenseCategory.transport,
      labelEn: 'Transport',
      labelVi: 'Di chuyển',
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
      icon: Icons.directions_car,
      color: Colors.blue,
    ),
    ExpenseCategory.shopping: Category(
      type: ExpenseCategory.shopping,
      labelEn: 'Shopping',
      labelVi: 'Mua sắm',
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
      icon: Icons.shopping_bag,
      color: Colors.purple,
    ),
    ExpenseCategory.bills: Category(
      type: ExpenseCategory.bills,
      labelEn: 'Bills',
      labelVi: 'Hóa đơn',
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
      icon: Icons.receipt_long,
      color: Colors.red,
    ),
    ExpenseCategory.health: Category(
      type: ExpenseCategory.health,
      labelEn: 'Health',
      labelVi: 'Sức khỏe',
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
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    ExpenseCategory.entertainment: Category(
      type: ExpenseCategory.entertainment,
      labelEn: 'Entertainment',
      labelVi: 'Giải trí',
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
      icon: Icons.movie,
      color: Colors.pink,
    ),
    ExpenseCategory.other: Category(
      type: ExpenseCategory.other,
      labelEn: 'Other',
      labelVi: 'Khác',
      keywordsEn: ['other', 'misc', 'miscellaneous'],
      keywordsVi: ['khác', 'khác'],
      icon: Icons.more_horiz,
      color: Colors.grey,
    ),
  };

  /// Get category by type
  static Category getByType(ExpenseCategory type) {
    return categories[type]!;
  }

  /// Get all categories as a list
  static List<Category> getAllCategories() {
    return categories.values.toList();
  }
}
