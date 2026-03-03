import Foundation

/// Lightweight localization helper that resolves String Catalog keys
/// for a specific language (not the system locale).
///
/// Usage:
///   L10n.tr("common.cancel", language)          // → "Hủy" / "Cancel"
///   L10n.tr("alert.daily_limit_message", language, 5)  // → format string with arg
enum L10n {
    /// Look up a String Catalog key for the given language code.
    static func tr(_ key: String, _ language: String) -> String {
        guard let bundle = bundle(for: language) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// Look up a String Catalog key with format arguments.
    static func tr(_ key: String, _ language: String, _ args: CVarArg...) -> String {
        let format = tr(key, language)
        return String(format: format, arguments: args)
    }

    // MARK: - Private

    private static func bundle(for language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback: if the requested language matches the base, use main bundle
            return language == "en" ? Bundle.main : nil
        }
        return bundle
    }
}
