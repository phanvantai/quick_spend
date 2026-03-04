# QuickSpend - Category & Group Reference (FINAL)

> Reviewed and finalized. All 26 categories have unique colors.

---

## Category Groups (7 unique groups)

### Expense Groups

| # | Group ID | EN | VI |
|---|----------|----|----|
| 1 | dailyLiving | Daily Living | Sinh hoạt hằng ngày |
| 2 | personal | Personal | Cá nhân |
| 3 | social | Social | Xã hội |
| 4 | financial | Financial | Tài chính |

### Income Groups

| # | Group ID | EN | VI |
|---|----------|----|----|
| 5 | earned | Earned | Thu nhập chủ động |
| 6 | passive | Passive | Thu nhập thụ động |
| 7 | received | Received | Nhận được |

### Shared Groups

| # | Group ID | EN | VI |
|---|----------|----|----|
| 8 | other | Other | Khác |

---

## EXPENSE Categories (18)

### Daily Living / Sinh hoạt hằng ngày (5)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 1 | food_drink | fork.knife | FF8C42 | Food & Drink | Ăn uống |
| 2 | groceries | cart.fill | 8BC34A | Groceries | Đi chợ / Siêu thị |
| 3 | transport | car.fill | 5F5CF1 | Transport | Di chuyển |
| 4 | housing | house.fill | 795548 | Housing | Nhà ở |
| 5 | bills_utilities | bolt.fill | FF5757 | Bills & Utilities | Hoá đơn |

### Personal / Cá nhân (5)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 6 | shopping | bag.fill | 6C5CE7 | Shopping | Mua sắm |
| 7 | health | cross.case.fill | 4CAF50 | Health | Sức khoẻ |
| 8 | education | book.fill | 3F51B5 | Education | Học tập |
| 9 | entertainment | film.fill | FF6B9D | Entertainment | Giải trí |
| 10 | personal_care | sparkles | E91E63 | Personal Care | Chăm sóc cá nhân |

### Social / Xã hội (2)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 11 | gifts | gift.fill | 9C27B0 | Gifts & Donations | Quà tặng |
| 12 | family | person.2.fill | 00BCD4 | Family | Gia đình |

### Financial / Tài chính (3)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 13 | insurance | shield.fill | 607D8B | Insurance | Bảo hiểm |
| 14 | savings_invest | chart.line.uptrend.xyaxis | 009688 | Savings & Investment | Tiết kiệm / Đầu tư |
| 15 | debt_payment | creditcard.fill | F44336 | Debt Payment | Trả nợ |

### Other / Khác (3)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 16 | pets | pawprint.fill | 8D6E63 | Pets | Thú cưng |
| 17 | travel | airplane | 00ACC1 | Travel | Du lịch |
| 18 | other_expense | ellipsis.circle.fill | 9E9EB5 | Other | Khác |

---

## INCOME Categories (8)

### Earned / Thu nhập chủ động (3)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 19 | salary | wallet.bifold.fill | 2E7D32 | Salary | Lương |
| 20 | freelance | laptopcomputer | 2196F3 | Freelance | Thu nhập tự do |
| 21 | bonus | star.fill | FFC107 | Bonus | Thưởng |

### Passive / Thu nhập thụ động (2)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 22 | investment_income | chart.bar.fill | 26A69A | Investment | Thu nhập đầu tư |
| 23 | interest | percent | 0288D1 | Interest | Lãi suất |

### Received / Nhận được (2)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 24 | gift_received | gift.fill | F06292 | Gift Received | Được tặng |
| 25 | refund | arrow.uturn.backward.circle.fill | FF9800 | Refund | Hoàn tiền |

### Other / Khác (1)

| # | ID | Icon (SF Symbol) | Color | EN Name | VI Name |
|---|----|-------------------|-------|---------|---------|
| 26 | other_income | plus.circle.fill | 7B1FA2 | Other Income | Thu nhập khác |

---

## Decisions Log

### Fixed: Duplicate Colors

All 26 categories now have unique colors. Changes applied to income categories:

| Category | Old Color | New Color | Reason |
|----------|-----------|-----------|--------|
| Salary | 4CAF50 | 2E7D32 | Conflicted with Health - shifted to darker green |
| Investment Income | 009688 | 26A69A | Conflicted with Savings & Investment - shifted to lighter teal |
| Interest | 00BCD4 | 0288D1 | Conflicted with Family - shifted to blue |
| Gift Received | E91E63 | F06292 | Conflicted with Personal Care - shifted to lighter pink |
| Other Income | 9C27B0 | 7B1FA2 | Conflicted with Gifts & Donations - shifted to deeper purple |

### Kept: Shared "Other" Group

Categories `other_expense` and `other_income` are already type-distinct. Splitting adds complexity with no UX benefit.

### Kept: "Social" (2 categories)

Merging into Personal would make it 7 items. Social spending (gifts, family) is conceptually distinct from personal consumption.

### Kept: "Received" (2 categories)

Gift Received and Refund don't fit Earned or Passive. They represent a distinct mental model of money received without work or investment.

---

## Summary

| Type | Groups | Categories |
|------|--------|------------|
| Expense | 4 + shared Other | 18 |
| Income | 3 + shared Other | 8 |
| **Total** | **7 unique groups** | **26 categories, 26 unique colors** |
