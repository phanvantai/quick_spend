# QuickSpend Changelog

---

## [2.4] - 2026-05-20

### What's New
- Voice input now understands date ranges with repetition: say "Monday to Friday last week, 20 for lunch each day" and get five separate expenses, each on the correct day
- Voice input understands relative weekdays and weeks in all four languages: "last Monday", "thứ 4 tuần trước", "先週月曜", "lunes pasado"
- Vietnamese voice input recognizes "triệu" as million (e.g. "5 triệu" = 5,000,000)

### Improvements
- Parser is more reliable: prompt now includes the actual calendar dates for this week and last week, so the AI no longer guesses weekday math
- Faster voice parsing: regex patterns for filler-word and "N days ago" detection are now compiled once instead of on every input

### Changed
- Voice recording UI extracted into its own layer so the rest of the home screen stays responsive while parsing
- Removed redundant CurrencyFormatter wrapper; all currency formatting now goes through AppConfig

### App Store Notes

#### en
What's New
• Date ranges that repeat: say "Monday to Friday last week, 20 for lunch each day" and get five expenses, one per day
• Recognizes relative weekdays and weeks in all four languages
• Vietnamese "triệu" now correctly parsed as million

Improvements
• More reliable voice parsing with explicit calendar context
• Faster voice input processing

#### vi
Tính năng mới
• Hiểu khoảng ngày lặp lại: nói "thứ 2 đến thứ 6 tuần trước mỗi ngày 180k tiền xe" và nhận đủ 5 giao dịch theo ngày
• Nhận diện thứ và tuần tương đối ở cả bốn ngôn ngữ
• "triệu" được hiểu chính xác là 1.000.000 đồng

Cải tiến
• Phân tích giọng nói chính xác hơn nhờ AI biết rõ ngày trong tuần
• Xử lý đầu vào giọng nói nhanh hơn

#### ja
新機能
• 繰り返しのある期間指定に対応：「先週月曜から金曜まで毎日500円交通費」で5件の取引を作成
• 4言語すべてで相対的な曜日・週の表現を認識
• より自然な日本語の音声入力

改善
• カレンダー情報を明示することで音声解析の精度が向上
• 音声入力の処理速度が向上

#### es
Novedades
• Rangos de fechas con repetición: di "de lunes a viernes la semana pasada, 3 euros cada día para transporte" y obtén cinco gastos
• Reconocimiento de días de la semana relativos en los cuatro idiomas
• Análisis de voz más natural

Mejoras
• Análisis de voz más fiable gracias al contexto explícito del calendario
• Procesamiento de entrada de voz más rápido

---

## [2.3] - 2026-04-16

### What's New
- Report screen: tap any category to see all its transactions in detail
- Calendar: tap a selected day again to deselect and view the full month

### Bug Fixes
- Fixed categories appearing duplicated after iCloud sync
- Fixed category picker items not responding to taps outside the text/icon area

### App Store Notes

#### en
What's New
• Report screen: tap any category to see all its transactions in detail
• Calendar: tap a selected day again to deselect and view the full month

Bug Fixes
• Fixed categories appearing duplicated after iCloud sync

#### vi
Tính năng mới
• Màn báo cáo: bấm vào danh mục để xem chi tiết toàn bộ giao dịch
• Lịch: bấm lại vào ngày đã chọn để bỏ chọn và xem cả tháng

Sửa lỗi
• Sửa lỗi danh mục bị trùng lặp sau khi đồng bộ iCloud

#### ja
新機能
• レポート画面：カテゴリをタップしてすべての取引を詳細表示
• カレンダー：選択済みの日付を再タップして選択解除し、月全体を表示

バグ修正
• iCloud同期後にカテゴリが重複表示される問題を修正

#### es
Novedades
• Informes: toca una categoría para ver todas sus transacciones en detalle
• Calendario: toca de nuevo el día seleccionado para deseleccionarlo y ver el mes completo

Correcciones
• Se corrigió la duplicación de categorías tras sincronizar con iCloud

---
