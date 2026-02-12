import Foundation
import SwiftUI
import SwiftData

/// Category model with support for both system and user-defined categories
@Model
final class QuickCategory {
    @Attribute(.unique) var id: String
    var name: String
    var keywords: [String]
    var iconName: String       // SF Symbol name
    var colorHex: String       // Hex color string (e.g. "FF8C42")
    var isSystem: Bool
    var userId: String?
    var typeRawValue: String
    var createdAt: Date

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var isIncomeCategory: Bool { type == .income }
    var isExpenseCategory: Bool { type == .expense }

    /// Resolved SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex)
    }

    init(
        id: String,
        name: String,
        keywords: [String],
        iconName: String,
        colorHex: String,
        isSystem: Bool,
        userId: String? = nil,
        type: TransactionType,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.iconName = iconName
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.userId = userId
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
    }

    // MARK: - Default System Categories

    /// Get localized category name for a given category ID and language
    static func categoryName(for id: String, language: String) -> String {
        let names: [String: [String: String]] = [
            "food": ["en": "Food", "vi": "An uong", "ja": "食費", "ko": "식비", "th": "อาหาร", "es": "Comida"],
            "transport": ["en": "Transport", "vi": "Di chuyen", "ja": "交通費", "ko": "교통비", "th": "การเดินทาง", "es": "Transporte"],
            "shopping": ["en": "Shopping", "vi": "Mua sam", "ja": "買い物", "ko": "쇼핑", "th": "ช็อปปิ้ง", "es": "Compras"],
            "bills": ["en": "Bills", "vi": "Hoa don", "ja": "支払い", "ko": "공과금", "th": "ค่าใช้จ่าย", "es": "Facturas"],
            "health": ["en": "Health", "vi": "Suc khoe", "ja": "健康", "ko": "건강", "th": "สุขภาพ", "es": "Salud"],
            "entertainment": ["en": "Entertainment", "vi": "Giai tri", "ja": "娯楽", "ko": "여가", "th": "บันเทิง", "es": "Entretenimiento"],
            "other": ["en": "Other", "vi": "Khac", "ja": "その他", "ko": "기타", "th": "อื่นๆ", "es": "Otros"],
            "salary": ["en": "Salary", "vi": "Luong", "ja": "給与", "ko": "급여", "th": "เงินเดือน", "es": "Salario"],
            "freelance": ["en": "Freelance", "vi": "Lam them", "ja": "副業", "ko": "프리랜스", "th": "งานอิสระ", "es": "Freelance"],
            "investment": ["en": "Investment", "vi": "Dau tu", "ja": "投資", "ko": "투자", "th": "การลงทุน", "es": "Inversión"],
            "gift_received": ["en": "Gift", "vi": "Qua tang", "ja": "ギフト", "ko": "선물", "th": "ของขวัญ", "es": "Regalo"],
            "refund": ["en": "Refund", "vi": "Hoan tien", "ja": "返金", "ko": "환불", "th": "คืนเงิน", "es": "Reembolso"],
            "other_income": ["en": "Other Income", "vi": "Thu nhap khac", "ja": "その他の収入", "ko": "기타 수입", "th": "รายได้อื่นๆ", "es": "Otros ingresos"],
        ]
        return names[id]?[language] ?? names[id]?["en"] ?? id
    }

    /// Get localized keywords for a given category ID and language
    static func categoryKeywords(for id: String, language: String) -> [String] {
        let keywords: [String: [String: [String]]] = [
            "food": [
                "en": ["food", "eat", "lunch", "dinner", "breakfast", "coffee", "drink", "restaurant", "cafe", "pizza", "burger", "snack", "meal", "groceries"],
                "vi": ["an", "com", "pho", "bun", "ca phe", "cafe", "tra", "nuoc", "uong", "sang", "trua", "toi", "quan", "nha hang", "an vat", "do an", "thuc an", "rau", "thit", "ca"],
                "ja": ["食事", "食べる", "朝食", "昼食", "夕食", "コーヒー", "飲み物", "レストラン", "カフェ", "ランチ", "食費", "食料品"],
                "ko": ["음식", "식사", "아침", "점심", "저녁", "커피", "카페", "레스토랑", "식당", "간식", "식료품"],
                "th": ["อาหาร", "กิน", "อาหารเช้า", "อาหารกลางวัน", "อาหารเย็น", "กาแฟ", "เครื่องดื่ม", "ร้านอาหาร", "คาเฟ่"],
                "es": ["comida", "comer", "desayuno", "almuerzo", "cena", "café", "bebida", "restaurante", "pizza", "snack", "comestibles"],
            ],
            "transport": [
                "en": ["transport", "taxi", "uber", "grab", "bus", "train", "metro", "parking", "gas", "petrol", "fuel", "car", "bike", "motorbike", "toll"],
                "vi": ["xe", "taxi", "grab", "xang", "dau", "bus", "xe buyt", "tau", "metro", "do xe", "gui xe", "o to", "xe may", "phi", "cau duong", "di chuyen"],
                "ja": ["交通", "タクシー", "バス", "電車", "地下鉄", "駐車場", "ガソリン", "燃料", "車", "バイク", "通行料", "交通費"],
                "ko": ["교통", "택시", "버스", "지하철", "주차", "기름", "휘발유", "차", "자동차", "오토바이", "통행료", "교통비"],
                "th": ["การเดินทาง", "แท็กซี่", "รถบัส", "รถไฟ", "จอดรถ", "น้ำมัน", "รถยนต์", "รถจักรยานยนต์", "ค่าผ่านทาง"],
                "es": ["transporte", "taxi", "uber", "autobús", "tren", "metro", "estacionamiento", "gasolina", "combustible", "coche", "moto", "peaje"],
            ],
            "shopping": [
                "en": ["shopping", "shop", "buy", "clothes", "shoes", "mall", "store", "gift", "book", "electronics", "purchase"],
                "vi": ["mua", "shopping", "quan ao", "giay", "dep", "ao", "vay", "do", "sieu thi", "cho", "qua", "tang", "sach", "dien thoai", "may tinh"],
                "ja": ["買い物", "ショッピング", "服", "靴", "モール", "店", "ギフト", "本", "電化製品", "購入"],
                "ko": ["쇼핑", "구매", "옷", "신발", "쇼핑몰", "선물", "책", "전자제품", "물건"],
                "th": ["ช็อปปิ้ง", "ซื้อ", "เสื้อผ้า", "รองเท้า", "ห้าง", "ร้าน", "ของขวัญ", "หนังสือ", "อิเล็กทรอนิกส์"],
                "es": ["compras", "comprar", "ropa", "zapatos", "centro comercial", "tienda", "regalo", "libro", "electrónica"],
            ],
            "bills": [
                "en": ["bill", "rent", "electricity", "water", "internet", "phone", "utility", "insurance", "subscription"],
                "vi": ["hoa don", "tien nha", "dien", "nuoc", "internet", "wifi", "dien thoai", "bao hiem", "thue", "phi"],
                "ja": ["支払い", "家賃", "電気", "水道", "インターネット", "電話", "光熱費", "保険", "サブスクリプション"],
                "ko": ["공과금", "청구서", "월세", "전기", "수도", "인터넷", "전화", "보험", "구독"],
                "th": ["ค่าใช้จ่าย", "ค่าเช่า", "ค่าไฟ", "ค่าน้ำ", "อินเทอร์เน็ต", "โทรศัพท์", "ประกัน", "สมาชิก"],
                "es": ["factura", "alquiler", "electricidad", "agua", "internet", "teléfono", "seguro", "suscripción"],
            ],
            "health": [
                "en": ["health", "medicine", "doctor", "hospital", "pharmacy", "drug", "clinic", "medical", "gym", "fitness"],
                "vi": ["thuoc", "bac si", "benh vien", "kham", "y te", "suc khoe", "nha thuoc", "phong kham", "gym", "the duc"],
                "ja": ["健康", "薬", "医者", "病院", "薬局", "クリニック", "医療", "ジム", "フィットネス"],
                "ko": ["건강", "약", "의사", "병원", "약국", "클리닉", "의료", "헬스장", "피트니스"],
                "th": ["สุขภาพ", "ยา", "หมอ", "โรงพยาบาล", "ร้านขายยา", "คลินิก", "ฟิตเนส"],
                "es": ["salud", "medicina", "médico", "hospital", "farmacia", "clínica", "gimnasio", "fitness"],
            ],
            "entertainment": [
                "en": ["entertainment", "movie", "cinema", "game", "music", "concert", "party", "fun", "hobby", "sport"],
                "vi": ["giai tri", "phim", "rap", "cinema", "game", "nhac", "ca nhac", "tiec", "vui choi", "the thao", "bong da"],
                "ja": ["娯楽", "映画", "シネマ", "ゲーム", "音楽", "コンサート", "パーティー", "趣味", "スポーツ"],
                "ko": ["여가", "영화", "게임", "음악", "콘서트", "파티", "취미", "스포츠", "오락"],
                "th": ["บันเทิง", "หนัง", "โรงภาพยนตร์", "เกม", "เพลง", "คอนเสิร์ต", "งานเลี้ยง", "กีฬา"],
                "es": ["entretenimiento", "película", "cine", "juego", "música", "concierto", "fiesta", "deporte", "hobby"],
            ],
            "other": [
                "en": ["other", "misc", "miscellaneous"],
                "vi": ["khac"],
                "ja": ["その他", "他"],
                "ko": ["기타", "기타비용"],
                "th": ["อื่นๆ"],
                "es": ["otros", "varios"],
            ],
            "salary": [
                "en": ["salary", "wage", "paycheck", "income", "payment", "pay", "work", "job", "earnings"],
                "vi": ["luong", "tien luong", "cong", "luong thang", "thu nhap", "tra luong", "nhan luong"],
                "ja": ["給与", "給料", "賃金", "収入", "支払い", "仕事", "所得"],
                "ko": ["급여", "월급", "봉급", "수입", "월급날", "소득"],
                "th": ["เงินเดือน", "รายได้", "ค่าจ้าง", "เงินได้", "งาน"],
                "es": ["salario", "sueldo", "pago", "ingreso", "nómina", "trabajo"],
            ],
            "freelance": [
                "en": ["freelance", "side job", "side hustle", "gig", "project", "contract", "part time", "extra income"],
                "vi": ["lam them", "freelance", "tu do", "du an", "hop dong", "part time", "lam ngoai", "thu nhap phu"],
                "ja": ["副業", "フリーランス", "サイドワーク", "プロジェクト", "契約", "パートタイム", "追加収入"],
                "ko": ["프리랜스", "부업", "사이드잡", "프로젝트", "계약", "파트타임", "추가수입"],
                "th": ["งานอิสระ", "ฟรีแลนซ์", "งานเสริม", "โปรเจกต์", "สัญญา", "พาร์ทไทม์"],
                "es": ["freelance", "trabajo extra", "proyecto", "contrato", "medio tiempo", "ingreso extra"],
            ],
            "investment": [
                "en": ["investment", "dividend", "interest", "stock", "profit", "return", "capital gain", "bond", "crypto"],
                "vi": ["dau tu", "co tuc", "lai", "co phieu", "loi nhuan", "sinh loi", "chung khoan", "tien lai"],
                "ja": ["投資", "配当", "利子", "株", "利益", "リターン", "債券", "暗号通貨"],
                "ko": ["투자", "배당금", "이자", "주식", "수익", "채권", "암호화폐"],
                "th": ["การลงทุน", "เงินปันผล", "ดอกเบี้ย", "หุ้น", "กำไร", "พันธบัตร"],
                "es": ["inversión", "dividendo", "interés", "acción", "ganancia", "retorno", "bono", "cripto"],
            ],
            "gift_received": [
                "en": ["gift", "present", "lucky money", "bonus", "reward", "prize", "red envelope", "allowance"],
                "vi": ["qua", "qua tang", "li xi", "tien mung", "thuong", "giai thuong", "phan thuong", "tien li xi"],
                "ja": ["ギフト", "プレゼント", "お年玉", "ボーナス", "報酬", "賞金", "お小遣い"],
                "ko": ["선물", "보너스", "상금", "보상", "세뱃돈", "용돈"],
                "th": ["ของขวัญ", "โบนัส", "รางวัล", "เงินอั่งเปา", "เงินกิ๊ฟ"],
                "es": ["regalo", "presente", "dinero de suerte", "bono", "recompensa", "premio"],
            ],
            "refund": [
                "en": ["refund", "return", "reimbursement", "cashback", "payback", "repayment"],
                "vi": ["hoan tien", "hoan lai", "tra lai", "cashback", "hoan"],
                "ja": ["返金", "返品", "払い戻し", "キャッシュバック", "返済"],
                "ko": ["환불", "반환", "상환", "캐시백"],
                "th": ["คืนเงิน", "เงินคืน", "แคชแบ็ก"],
                "es": ["reembolso", "devolución", "reintegro", "cashback"],
            ],
            "other_income": [
                "en": ["other income", "miscellaneous income", "extra"],
                "vi": ["thu nhap khac", "thu khac"],
                "ja": ["その他の収入", "雑収入", "その他"],
                "ko": ["기타 수입", "기타 소득"],
                "th": ["รายได้อื่นๆ", "รายได้เบ็ดเตล็ด"],
                "es": ["otros ingresos", "ingreso misceláneo", "extra"],
            ],
        ]
        return keywords[id]?[language] ?? keywords[id]?["en"] ?? [id]
    }

    /// Get all default system categories for a given language
    static func defaultSystemCategories(language: String) -> [QuickCategory] {
        struct CategoryDef {
            let id: String
            let iconName: String
            let colorHex: String
            let type: TransactionType
        }

        let definitions: [CategoryDef] = [
            // Expense categories
            CategoryDef(id: "food", iconName: "fork.knife", colorHex: "FF8C42", type: .expense),
            CategoryDef(id: "transport", iconName: "car.fill", colorHex: "5F5CF1", type: .expense),
            CategoryDef(id: "shopping", iconName: "bag.fill", colorHex: "6C5CE7", type: .expense),
            CategoryDef(id: "bills", iconName: "doc.text.fill", colorHex: "FF5757", type: .expense),
            CategoryDef(id: "health", iconName: "cross.case.fill", colorHex: "4CAF50", type: .expense),
            CategoryDef(id: "entertainment", iconName: "film.fill", colorHex: "FF6B9D", type: .expense),
            CategoryDef(id: "other", iconName: "ellipsis.circle.fill", colorHex: "9E9EB5", type: .expense),
            // Income categories
            CategoryDef(id: "salary", iconName: "wallet.bifold.fill", colorHex: "4CAF50", type: .income),
            CategoryDef(id: "freelance", iconName: "laptopcomputer", colorHex: "2196F3", type: .income),
            CategoryDef(id: "investment", iconName: "chart.line.uptrend.xyaxis", colorHex: "009688", type: .income),
            CategoryDef(id: "gift_received", iconName: "gift.fill", colorHex: "E91E63", type: .income),
            CategoryDef(id: "refund", iconName: "arrow.uturn.backward.circle.fill", colorHex: "FF9800", type: .income),
            CategoryDef(id: "other_income", iconName: "plus.circle.fill", colorHex: "9C27B0", type: .income),
        ]

        return definitions.map { def in
            QuickCategory(
                id: def.id,
                name: categoryName(for: def.id, language: language),
                keywords: categoryKeywords(for: def.id, language: language),
                iconName: def.iconName,
                colorHex: def.colorHex,
                isSystem: true,
                userId: nil,
                type: def.type
            )
        }
    }
}
