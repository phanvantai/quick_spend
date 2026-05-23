# QuickSpend Changelog

---

## [3.0] - 2026-05-23

### What's New
- **App Intents + Siri shortcut** — say "Hey Siri, add expense 50k coffee" from anywhere to log an expense without opening the app
- **Auto-save high-confidence Siri parses** — when the AI is at least 90% confident, the expense saves instantly with just a quick confirmation snippet; ambiguous parses still ask before logging
- **3-step onboarding** — language/currency → starting balance (with skip) → Try Siri demo. Fresh installs now seed a BalanceAnchor when you enter an amount
- **Home v3.0** — new BalanceHero with accent stripe, dot pattern background, and inline "this month" delta chip
- **Focal chart card** — toggle between donut (by category) and bar (income vs expense) on Home; selection persists across launches
- **Voice FAB redesign** — Listening Orb with conic-gradient sweep that rotates slowly when idle, fast while recording. Soundlevel-reactive halo glow
- **Settings as a sheet** — opens from the gear icon in the toolbar; large detent with drag-to-dismiss

### Improvements
- Tabs reduced from 3 to 2 (Home, Transactions). Settings + Add Manual moved to toolbar icons
- New design system tokens: Typography scale, AnimationPreset (springFast/Smooth/Gentle, easeQuick), AppShadow, Motion
- Onboarding paginated with smooth TabView spring transitions
- Transactions polish: typography tokens applied across calendar grid, month navigator, summary section, and date headers
- Calendar day select and month-chevron transitions now use spring animations
- Voice FAB rotation stays continuous across record/idle transitions — no more snap back to 12 o'clock
- TransactionFormView refactored from 591 LOC into focused components (TypeToggle, AmountInputField, CategoryPickerField, DateRow, NoteField)
- SettingsView refactored from 454 LOC into section subviews (Core, Subscription, Data, Preferences) with a centralized sheet router
- VoiceCaptureViewModel extracted from VoiceFABLayer for testability — 9 new unit tests
- Modal screens consolidated via reusable ModalTemplate + ModalGradientHero

### Bug Fixes
- Opening a sheet from inside Settings (BalanceEdit, picker, paywall) no longer dismisses both sheets
- Fresh installs no longer see the Siri promo modal after completing the Try Siri onboarding step
- VoiceFAB sweep animation now keeps moving smoothly when you release the record gesture

### App Store Notes

#### en
What's New
• Hey Siri, add expense — log spending from anywhere without opening the app
• High-confidence Siri parses save instantly — no tap needed when the AI is sure
• Redesigned home with a bigger balance hero, monthly delta chip, and a focal chart you can flip between donut and bar
• Onboarding now sets your starting balance and teaches the Siri shortcut in three quick steps
• Brand new Listening Orb voice button with a smooth conic-gradient sweep

Improvements
• Cleaner 2-tab layout with Settings and Add Manual as toolbar icons
• Spring-based motion throughout the app
• Big internal refactor — smaller, faster, easier to maintain

Bug Fixes
• Settings sheets no longer dismiss accidentally when opening a sub-sheet
• Fresh installs no longer see duplicate Siri prompts

#### vi
Tính năng mới
• Hey Siri, thêm chi tiêu — ghi chi phí từ bất cứ đâu mà không cần mở app
• Lệnh Siri được phân tích chắc chắn sẽ tự lưu ngay — không cần bấm xác nhận khi AI đã chắc
• Trang chính được thiết kế lại với BalanceHero lớn hơn, chip biến động trong tháng, và biểu đồ tiêu điểm chuyển giữa donut và bar
• Onboarding 3 bước: thiết lập số dư ban đầu và hướng dẫn dùng Siri shortcut
• Nút voice "Listening Orb" mới với hiệu ứng conic-gradient mượt mà

Cải tiến
• Bố cục 2 tab gọn hơn, Settings và Thêm thủ công chuyển vào toolbar
• Animation kiểu spring xuyên suốt app
• Refactor nội bộ lớn — nhỏ hơn, nhanh hơn, dễ bảo trì hơn

Sửa lỗi
• Sheet trong Settings không còn vô tình đóng khi mở sub-sheet
• Người mới cài không còn thấy lời nhắc Siri trùng lặp

#### ja
新機能
• 「Hey Siri、出費を追加して」— アプリを開かずにどこからでも記録
• AIの確信度が高い場合はSiri解析が即座に保存 — 確認タップ不要
• 大きな残高ヒーロー、今月の増減チップ、ドーナツ/棒グラフ切替の焦点チャートで再設計されたホーム
• 開始残高の設定とSiriショートカットの紹介を含む3ステップのオンボーディング
• 滑らかなコニックグラデーション・スイープを持つ新しい「Listening Orb」音声ボタン

改善
• 設定と手動追加をツールバーアイコンに移動した、よりすっきりした2タブ構成
• アプリ全体でスプリングベースのモーション
• 大規模な内部リファクタ — より小さく、速く、保守しやすく

バグ修正
• 設定内でサブシートを開いたときに誤って閉じることがなくなりました
• 新規インストール後にSiriプロンプトが重複表示されることがなくなりました

#### es
Novedades
• Oye Siri, añade gasto — registra gastos desde cualquier lugar sin abrir la app
• Los análisis de Siri con alta confianza se guardan al instante — sin necesidad de tocar para confirmar
• Inicio rediseñado con un hero de saldo más grande, chip de variación mensual y gráfico focal alternable entre dona y barras
• Onboarding en 3 pasos: configura tu saldo inicial y aprende el atajo de Siri
• Nuevo botón de voz "Listening Orb" con barrido cónico-degradado suave

Mejoras
• Diseño más limpio de 2 pestañas con Ajustes y Añadir manual en la barra de herramientas
• Animaciones tipo resorte en toda la app
• Gran refactor interno — más pequeño, más rápido, más fácil de mantener

Correcciones
• Las hojas de Ajustes ya no se cierran accidentalmente al abrir una sub-hoja
• Las instalaciones nuevas ya no ven indicaciones duplicadas de Siri

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
