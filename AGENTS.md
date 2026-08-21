# Repository Guidelines

## Project Structure & Module Organization

`QuickSpend/` contains the iOS application. Keep SwiftData entities and value types in `Models/`, business and integration logic in `Services/`, observable state in `ViewModels/`, reusable helpers in `Utilities/`, and design tokens in `Theme/`. SwiftUI screens are grouped by feature under `Views/`; App Intents and shortcuts live in `Intents/`. Unit tests are in `QuickSpendTests/`, while launch and end-to-end checks are in `QuickSpendUITests/`. `quickspend-landing/` is the static GitHub Pages site, `screenshot-generator/` is a separate Next.js tool, and `screenshots/` stores generated marketing assets.

## Build, Test, and Development Commands

- `open QuickSpend.xcodeproj` opens the app in Xcode 16+; select the `QuickSpend` scheme and an iOS 18+ simulator.
- `xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator build` resolves Swift Package Manager dependencies and builds the app.
- `xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator test` runs unit and UI test targets.
- Add `-only-testing:QuickSpendTests/TransactionTests` before `test` to run one suite.
- In `screenshot-generator/`, run `npm install`, then `npm run dev` or `npm run build`. The static landing page needs no local build step.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift API naming: types in `UpperCamelCase`, methods and properties in `lowerCamelCase`, and one primary type per file named after that type. Keep views small, move logic into testable services or view models, and reuse `AppTheme` and `Views/Components` instead of duplicating styling. Preserve `#if canImport(...)` guards around optional Firebase and RevenueCat integrations. No repository-wide Swift formatter or linter is configured; use Xcode formatting and keep diffs warning-free.

## Testing Guidelines

Use Swift Testing (`@Test`, `#expect`) for new unit tests and XCTest for UI tests. Name files `<Subject>Tests.swift`. Follow TDD for behavior changes and add a regression test for every bug fix. Tests must be isolated and offline: use artificial fixtures, test-specific `UserDefaults`, in-memory SwiftData containers, and mocked external services. There is no numeric coverage threshold, but all logic-bearing changes require tests.

## Commit & Pull Request Guidelines

Follow the history's Conventional Commit style, such as `feat(home): ...`, `fix(intent): ...`, `test(appConfig): ...`, or `docs(changelog): ...`. Keep commits focused. Pull requests should explain user-visible behavior, list verification performed, link relevant issues, and include screenshots or recordings for UI changes. Update `CHANGELOG.md` for releases, including App Store notes in English, Vietnamese, Japanese, and Spanish. Never commit new API keys or production user data.
