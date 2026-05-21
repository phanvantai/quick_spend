# QuickSpend Changelog

---

## [2.4.1] - 2026-05-21

### Improvements
- Balance card now updates instantly when you add, edit, or delete a transaction — no more waiting for the recompute to catch up
- The "Edit Balance" sheet now pre-fills with your current running balance instead of the original opening balance

### Bug Fixes
- Filled missing localizations in Vietnamese, Japanese, and Spanish for common UI strings (Cancel, Delete, Edit, Amount, Month, Day, Status, Type, etc.)

### App Store Notes

#### en
What's New
• Balance updates instantly when you add, edit, or delete a transaction — no waiting

Bug Fixes
• Edit Balance now pre-fills with your current balance, not the original opening value
• Filled in missing translations for common UI strings

#### vi
Tính năng mới
• Số dư cập nhật ngay khi bạn thêm, sửa hoặc xoá giao dịch — không cần chờ

Sửa lỗi
• Sửa số dư hiện điền sẵn số dư hiện tại, thay vì giá trị mở ban đầu
• Bổ sung các bản dịch còn thiếu cho các chuỗi giao diện thông dụng

#### ja
新機能
• 取引の追加・編集・削除と同時に残高が即座に更新されます — 待ち時間なし

バグ修正
• 残高編集画面に、開始残高ではなく現在の残高が初期表示されるようになりました
• 共通UI文字列の不足していた翻訳を追加

#### es
Novedades
• El saldo se actualiza al instante al añadir, editar o eliminar una transacción — sin esperas

Correcciones
• Editar saldo ahora se rellena con tu saldo actual, no con el valor inicial
• Se completaron las traducciones faltantes en cadenas de UI comunes

---

## [2.4] - 2026-05-20

### What's New
- Account balance card on Home — see your total balance at a glance, separate from the monthly stats below
- Balance updates automatically with every transaction and syncs across all your iCloud devices
- Edit your opening balance any time from Settings or by tapping the balance card
- Voice input now understands date ranges with repetition: say "Monday to Friday last week, 20 for lunch each day" and get five separate expenses, each on the correct day
- Voice input understands relative weekdays and weeks in all four languages: "last Monday", "thứ 4 tuần trước", "先週月曜", "lunes pasado"
- Vietnamese voice input recognizes "triệu" as million (e.g. "5 triệu" = 5,000,000)

### Improvements
- Parser is more reliable: prompt now includes the actual calendar dates for this week and last week, so the AI no longer guesses weekday math
- Faster voice parsing: regex patterns for filler-word and "N days ago" detection are now compiled once instead of on every input

### Changed
- Voice recording UI extracted into its own layer so the rest of the home screen stays responsive while parsing
- Removed redundant CurrencyFormatter wrapper; all currency formatting now goes through AppConfig
- Saved app preferences are now decoded forward-compatibly — adding new fields in future versions no longer risks wiping language/currency/theme settings

### App Store Notes

#### en
What's New
• Account balance on Home: total balance at a glance, updates with every transaction, syncs across iCloud
• Edit your opening balance any time from Settings or by tapping the balance card
• Date ranges that repeat: say "Monday to Friday last week, 20 for lunch each day" and get five expenses, one per day
• Recognizes relative weekdays and weeks in all four languages
• Vietnamese "triệu" now correctly parsed as million

Improvements
• More reliable voice parsing with explicit calendar context
• Faster voice input processing

#### vi
Tính năng mới
• Số dư tài khoản trên màn hình chính: xem tổng số dư mọi lúc, tự cập nhật theo từng giao dịch, đồng bộ qua iCloud
• Chỉnh sửa số dư ban đầu bất kỳ lúc nào trong Cài đặt hoặc chạm vào thẻ số dư
• Hiểu khoảng ngày lặp lại: nói "thứ 2 đến thứ 6 tuần trước mỗi ngày 180k tiền xe" và nhận đủ 5 giao dịch theo ngày
• Nhận diện thứ và tuần tương đối ở cả bốn ngôn ngữ
• "triệu" được hiểu chính xác là 1.000.000 đồng

Cải tiến
• Phân tích giọng nói chính xác hơn nhờ AI biết rõ ngày trong tuần
• Xử lý đầu vào giọng nói nhanh hơn

#### ja
新機能
• ホーム画面の口座残高：累計残高をひと目で確認、取引ごとに自動更新、iCloudで同期
• 開始残高は設定からいつでも編集可能
• 繰り返しのある期間指定に対応：「先週月曜から金曜まで毎日500円交通費」で5件の取引を作成
• 4言語すべてで相対的な曜日・週の表現を認識
• より自然な日本語の音声入力

改善
• カレンダー情報を明示することで音声解析の精度が向上
• 音声入力の処理速度が向上

#### es
Novedades
• Saldo de la cuenta en Inicio: saldo total de un vistazo, se actualiza con cada transacción, se sincroniza por iCloud
• Edita tu saldo inicial en cualquier momento desde Ajustes o tocando la tarjeta de saldo
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
