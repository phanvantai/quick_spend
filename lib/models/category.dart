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
  /// [language] should be 'en', 'vi', 'ja', 'ko', 'th', or 'es'
  static List<QuickCategory> getDefaultSystemCategories(String language) {
    final now = DateTime.now();

    // Helper to get localized category name
    String getCategoryName(String id) {
      final names = {
        'food': {'en': 'Food', 'vi': 'Ăn uống', 'ja': '食費', 'ko': '식비', 'th': 'อาหาร', 'es': 'Comida'},
        'transport': {'en': 'Transport', 'vi': 'Di chuyển', 'ja': '交通費', 'ko': '교통비', 'th': 'การเดินทาง', 'es': 'Transporte'},
        'shopping': {'en': 'Shopping', 'vi': 'Mua sắm', 'ja': '買い物', 'ko': '쇼핑', 'th': 'ช็อปปิ้ง', 'es': 'Compras'},
        'bills': {'en': 'Bills', 'vi': 'Hóa đơn', 'ja': '支払い', 'ko': '공과금', 'th': 'ค่าใช้จ่าย', 'es': 'Facturas'},
        'health': {'en': 'Health', 'vi': 'Sức khỏe', 'ja': '健康', 'ko': '건강', 'th': 'สุขภาพ', 'es': 'Salud'},
        'entertainment': {'en': 'Entertainment', 'vi': 'Giải trí', 'ja': '娯楽', 'ko': '여가', 'th': 'บันเทิง', 'es': 'Entretenimiento'},
        'other': {'en': 'Other', 'vi': 'Khác', 'ja': 'その他', 'ko': '기타', 'th': 'อื่นๆ', 'es': 'Otros'},
        'salary': {'en': 'Salary', 'vi': 'Lương', 'ja': '給与', 'ko': '급여', 'th': 'เงินเดือน', 'es': 'Salario'},
        'freelance': {'en': 'Freelance', 'vi': 'Làm thêm', 'ja': '副業', 'ko': '프리랜스', 'th': 'งานอิสระ', 'es': 'Freelance'},
        'investment': {'en': 'Investment', 'vi': 'Đầu tư', 'ja': '投資', 'ko': '투자', 'th': 'การลงทุน', 'es': 'Inversión'},
        'gift_received': {'en': 'Gift', 'vi': 'Quà tặng', 'ja': 'ギフト', 'ko': '선물', 'th': 'ของขวัญ', 'es': 'Regalo'},
        'refund': {'en': 'Refund', 'vi': 'Hoàn tiền', 'ja': '返金', 'ko': '환불', 'th': 'คืนเงิน', 'es': 'Reembolso'},
        'other_income': {'en': 'Other Income', 'vi': 'Thu nhập khác', 'ja': 'その他の収入', 'ko': '기타 수입', 'th': 'รายได้อื่นๆ', 'es': 'Otros ingresos'},
      };
      return names[id]?[language] ?? names[id]?['en'] ?? id;
    }

    // Helper to get localized keywords
    List<String> getCategoryKeywords(String id) {
      final keywords = {
        'food': {
          'en': ['food', 'eat', 'lunch', 'dinner', 'breakfast', 'coffee', 'drink', 'restaurant', 'cafe', 'pizza', 'burger', 'snack', 'meal', 'groceries'],
          'vi': ['ăn', 'cơm', 'phở', 'bún', 'cà phê', 'cafe', 'trà', 'nước', 'uống', 'sáng', 'trưa', 'tối', 'quán', 'nhà hàng', 'ăn vặt', 'đồ ăn', 'thức ăn', 'rau', 'thịt', 'cá'],
          'ja': ['食事', '食べる', '朝食', '昼食', '夕食', 'コーヒー', '飲み物', 'レストラン', 'カフェ', 'ランチ', '食費', '食料品'],
          'ko': ['음식', '식사', '아침', '점심', '저녁', '커피', '카페', '레스토랑', '식당', '간식', '식료품'],
          'th': ['อาหาร', 'กิน', 'อาหารเช้า', 'อาหารกลางวัน', 'อาหารเย็น', 'กาแฟ', 'เครื่องดื่ม', 'ร้านอาหาร', 'คาเฟ่'],
          'es': ['comida', 'comer', 'desayuno', 'almuerzo', 'cena', 'café', 'bebida', 'restaurante', 'pizza', 'snack', 'comestibles'],
        },
        'transport': {
          'en': ['transport', 'taxi', 'uber', 'grab', 'bus', 'train', 'metro', 'parking', 'gas', 'petrol', 'fuel', 'car', 'bike', 'motorbike', 'toll'],
          'vi': ['xe', 'taxi', 'grab', 'xăng', 'dầu', 'bus', 'xe buýt', 'tàu', 'metro', 'đỗ xe', 'gửi xe', 'ô tô', 'xe máy', 'phí', 'cầu đường', 'di chuyển'],
          'ja': ['交通', 'タクシー', 'バス', '電車', '地下鉄', '駐車場', 'ガソリン', '燃料', '車', 'バイク', '通行料', '交通費'],
          'ko': ['교통', '택시', '버스', '지하철', '주차', '기름', '휘발유', '차', '자동차', '오토바이', '통행료', '교통비'],
          'th': ['การเดินทาง', 'แท็กซี่', 'รถบัส', 'รถไฟ', 'จอดรถ', 'น้ำมัน', 'รถยนต์', 'รถจักรยานยนต์', 'ค่าผ่านทาง'],
          'es': ['transporte', 'taxi', 'uber', 'autobús', 'tren', 'metro', 'estacionamiento', 'gasolina', 'combustible', 'coche', 'moto', 'peaje'],
        },
        'shopping': {
          'en': ['shopping', 'shop', 'buy', 'clothes', 'shoes', 'mall', 'store', 'gift', 'book', 'electronics', 'purchase'],
          'vi': ['mua', 'shopping', 'quần áo', 'giày', 'dép', 'áo', 'váy', 'đồ', 'siêu thị', 'chợ', 'quà', 'tặng', 'sách', 'điện thoại', 'máy tính'],
          'ja': ['買い物', 'ショッピング', '服', '靴', 'モール', '店', 'ギフト', '本', '電化製品', '購入'],
          'ko': ['쇼핑', '구매', '옷', '신발', '쇼핑몰', '선물', '책', '전자제품', '물건'],
          'th': ['ช็อปปิ้ง', 'ซื้อ', 'เสื้อผ้า', 'รองเท้า', 'ห้าง', 'ร้าน', 'ของขวัญ', 'หนังสือ', 'อิเล็กทรอนิกส์'],
          'es': ['compras', 'comprar', 'ropa', 'zapatos', 'centro comercial', 'tienda', 'regalo', 'libro', 'electrónica'],
        },
        'bills': {
          'en': ['bill', 'rent', 'electricity', 'water', 'internet', 'phone', 'utility', 'insurance', 'subscription'],
          'vi': ['hóa đơn', 'tiền nhà', 'điện', 'nước', 'internet', 'wifi', 'điện thoại', 'bảo hiểm', 'thuê', 'phí'],
          'ja': ['支払い', '家賃', '電気', '水道', 'インターネット', '電話', '光熱費', '保険', 'サブスクリプション'],
          'ko': ['공과금', '청구서', '월세', '전기', '수도', '인터넷', '전화', '보험', '구독'],
          'th': ['ค่าใช้จ่าย', 'ค่าเช่า', 'ค่าไฟ', 'ค่าน้ำ', 'อินเทอร์เน็ต', 'โทรศัพท์', 'ประกัน', 'สมาชิก'],
          'es': ['factura', 'alquiler', 'electricidad', 'agua', 'internet', 'teléfono', 'seguro', 'suscripción'],
        },
        'health': {
          'en': ['health', 'medicine', 'doctor', 'hospital', 'pharmacy', 'drug', 'clinic', 'medical', 'gym', 'fitness'],
          'vi': ['thuốc', 'bác sĩ', 'bệnh viện', 'khám', 'y tế', 'sức khỏe', 'nhà thuốc', 'phòng khám', 'gym', 'thể dục'],
          'ja': ['健康', '薬', '医者', '病院', '薬局', 'クリニック', '医療', 'ジム', 'フィットネス'],
          'ko': ['건강', '약', '의사', '병원', '약국', '클리닉', '의료', '헬스장', '피트니스'],
          'th': ['สุขภาพ', 'ยา', 'หมอ', 'โรงพยาบาล', 'ร้านขายยา', 'คลินิก', 'ฟิตเนส'],
          'es': ['salud', 'medicina', 'médico', 'hospital', 'farmacia', 'clínica', 'gimnasio', 'fitness'],
        },
        'entertainment': {
          'en': ['entertainment', 'movie', 'cinema', 'game', 'music', 'concert', 'party', 'fun', 'hobby', 'sport'],
          'vi': ['giải trí', 'phim', 'rạp', 'cinema', 'game', 'nhạc', 'ca nhạc', 'tiệc', 'vui chơi', 'thể thao', 'bóng đá'],
          'ja': ['娯楽', '映画', 'シネマ', 'ゲーム', '音楽', 'コンサート', 'パーティー', '趣味', 'スポーツ'],
          'ko': ['여가', '영화', '게임', '음악', '콘서트', '파티', '취미', '스포츠', '오락'],
          'th': ['บันเทิง', 'หนัง', 'โรงภาพยนตร์', 'เกม', 'เพลง', 'คอนเสิร์ต', 'งานเลี้ยง', 'กีฬา'],
          'es': ['entretenimiento', 'película', 'cine', 'juego', 'música', 'concierto', 'fiesta', 'deporte', 'hobby'],
        },
        'other': {
          'en': ['other', 'misc', 'miscellaneous'],
          'vi': ['khác'],
          'ja': ['その他', '他'],
          'ko': ['기타', '기타비용'],
          'th': ['อื่นๆ'],
          'es': ['otros', 'varios'],
        },
        'salary': {
          'en': ['salary', 'wage', 'paycheck', 'income', 'payment', 'pay', 'work', 'job', 'earnings'],
          'vi': ['lương', 'tiền lương', 'công', 'lương tháng', 'thu nhập', 'trả lương', 'nhận lương'],
          'ja': ['給与', '給料', '賃金', '収入', '支払い', '仕事', '所得'],
          'ko': ['급여', '월급', '봉급', '수입', '월급날', '소득'],
          'th': ['เงินเดือน', 'รายได้', 'ค่าจ้าง', 'เงินได้', 'งาน'],
          'es': ['salario', 'sueldo', 'pago', 'ingreso', 'nómina', 'trabajo'],
        },
        'freelance': {
          'en': ['freelance', 'side job', 'side hustle', 'gig', 'project', 'contract', 'part time', 'extra income'],
          'vi': ['làm thêm', 'freelance', 'tự do', 'dự án', 'hợp đồng', 'part time', 'làm ngoài', 'thu nhập phụ'],
          'ja': ['副業', 'フリーランス', 'サイドワーク', 'プロジェクト', '契約', 'パートタイム', '追加収入'],
          'ko': ['프리랜스', '부업', '사이드잡', '프로젝트', '계약', '파트타임', '추가수입'],
          'th': ['งานอิสระ', 'ฟรีแลนซ์', 'งานเสริม', 'โปรเจกต์', 'สัญญา', 'พาร์ทไทม์'],
          'es': ['freelance', 'trabajo extra', 'proyecto', 'contrato', 'medio tiempo', 'ingreso extra'],
        },
        'investment': {
          'en': ['investment', 'dividend', 'interest', 'stock', 'profit', 'return', 'capital gain', 'bond', 'crypto'],
          'vi': ['đầu tư', 'cổ tức', 'lãi', 'cổ phiếu', 'lợi nhuận', 'sinh lời', 'chứng khoán', 'tiền lãi'],
          'ja': ['投資', '配当', '利子', '株', '利益', 'リターン', '債券', '暗号通貨'],
          'ko': ['투자', '배당금', '이자', '주식', '수익', '채권', '암호화폐'],
          'th': ['การลงทุน', 'เงินปันผล', 'ดอกเบี้ย', 'หุ้น', 'กำไร', 'พันธบัตร'],
          'es': ['inversión', 'dividendo', 'interés', 'acción', 'ganancia', 'retorno', 'bono', 'cripto'],
        },
        'gift_received': {
          'en': ['gift', 'present', 'lucky money', 'bonus', 'reward', 'prize', 'red envelope', 'allowance'],
          'vi': ['quà', 'quà tặng', 'lì xì', 'tiền mừng', 'thưởng', 'giải thưởng', 'phần thưởng', 'tiền lì xì'],
          'ja': ['ギフト', 'プレゼント', 'お年玉', 'ボーナス', '報酬', '賞金', 'お小遣い'],
          'ko': ['선물', '보너스', '상금', '보상', '세뱃돈', '용돈'],
          'th': ['ของขวัญ', 'โบนัส', 'รางวัล', 'เงินอั่งเปา', 'เงินกิ๊ฟ'],
          'es': ['regalo', 'presente', 'dinero de suerte', 'bono', 'recompensa', 'premio'],
        },
        'refund': {
          'en': ['refund', 'return', 'reimbursement', 'cashback', 'payback', 'repayment'],
          'vi': ['hoàn tiền', 'hoàn lại', 'trả lại', 'cashback', 'hoàn'],
          'ja': ['返金', '返品', '払い戻し', 'キャッシュバック', '返済'],
          'ko': ['환불', '반환', '상환', '캐시백'],
          'th': ['คืนเงิน', 'เงินคืน', 'แคชแบ็ก'],
          'es': ['reembolso', 'devolución', 'reintegro', 'cashback'],
        },
        'other_income': {
          'en': ['other income', 'miscellaneous income', 'extra'],
          'vi': ['thu nhập khác', 'thu khác'],
          'ja': ['その他の収入', '雑収入', 'その他'],
          'ko': ['기타 수입', '기타 소득'],
          'th': ['รายได้อื่นๆ', 'รายได้เบ็ดเตล็ด'],
          'es': ['otros ingresos', 'ingreso misceláneo', 'extra'],
        },
      };
      return keywords[id]?[language] ?? keywords[id]?['en'] ?? [id];
    }

    return [
      QuickCategory(
        id: 'food',
        name: getCategoryName('food'),
        keywords: getCategoryKeywords('food'),
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: Colors.orange.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'transport',
        name: getCategoryName('transport'),
        keywords: getCategoryKeywords('transport'),
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: Colors.blue.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'shopping',
        name: getCategoryName('shopping'),
        keywords: getCategoryKeywords('shopping'),
        iconCodePoint: Icons.shopping_bag.codePoint,
        colorValue: Colors.purple.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'bills',
        name: getCategoryName('bills'),
        keywords: getCategoryKeywords('bills'),
        iconCodePoint: Icons.receipt_long.codePoint,
        colorValue: Colors.red.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'health',
        name: getCategoryName('health'),
        keywords: getCategoryKeywords('health'),
        iconCodePoint: Icons.local_hospital.codePoint,
        colorValue: Colors.green.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'entertainment',
        name: getCategoryName('entertainment'),
        keywords: getCategoryKeywords('entertainment'),
        iconCodePoint: Icons.movie.codePoint,
        colorValue: Colors.pink.toARGB32(),
        isSystem: true,
        userId: null,
        type: TransactionType.expense,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other',
        name: getCategoryName('other'),
        keywords: getCategoryKeywords('other'),
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
        name: getCategoryName('salary'),
        keywords: getCategoryKeywords('salary'),
        iconCodePoint: Icons.account_balance_wallet.codePoint,
        colorValue: const Color(0xFF4CAF50).toARGB32(), // Green
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'freelance',
        name: getCategoryName('freelance'),
        keywords: getCategoryKeywords('freelance'),
        iconCodePoint: Icons.laptop_mac.codePoint,
        colorValue: const Color(0xFF2196F3).toARGB32(), // Blue
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'investment',
        name: getCategoryName('investment'),
        keywords: getCategoryKeywords('investment'),
        iconCodePoint: Icons.trending_up.codePoint,
        colorValue: const Color(0xFF009688).toARGB32(), // Teal
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'gift_received',
        name: getCategoryName('gift_received'),
        keywords: getCategoryKeywords('gift_received'),
        iconCodePoint: Icons.card_giftcard.codePoint,
        colorValue: const Color(0xFFE91E63).toARGB32(), // Pink
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'refund',
        name: getCategoryName('refund'),
        keywords: getCategoryKeywords('refund'),
        iconCodePoint: Icons.undo.codePoint,
        colorValue: const Color(0xFFFF9800).toARGB32(), // Orange
        isSystem: true,
        userId: null,
        type: TransactionType.income,
        createdAt: now,
      ),
      QuickCategory(
        id: 'other_income',
        name: getCategoryName('other_income'),
        keywords: getCategoryKeywords('other_income'),
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
