import Testing
import Foundation

/// App Store Connect rejects a build whose App Intent metadata names an Apple
/// device (ITMS-90626 "Invalid Siri Support … cannot contain 'iphone'"; build
/// 117 of 4.2 was rejected for this). Scans the intent titles, descriptions,
/// parameter texts and dialogs in the sources, and their translations in the
/// string catalogs.
@Suite("App Intent metadata")
struct AppIntentMetadataTests {

    private static let banned = ["iphone", "ipad", "ipod", "apple watch", "macbook"]
    private static let intentFolders = ["QuickSpend/Intents", "Shared"]
    private static let catalogs = ["QuickSpend/Localizable.xcstrings", "QuickSpendWidgets/Localizable.xcstrings"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// String literals passed as intent metadata.
    private static let metadataLiteral = try! NSRegularExpression(
        pattern: #"(?:IntentDescription\(|LocalizedStringResource\s*=|title:|description:|requestValueDialog:\s*IntentDialog\(|DisplayRepresentation\s*=|:\s*)\s*\n?\s*"((?:[^"\\]|\\.)+)""#
    )

    private func metadataStrings() throws -> [String] {
        var strings: [String] = []
        for folder in Self.intentFolders {
            let url = Self.repoRoot.appendingPathComponent(folder)
            guard let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where file.pathExtension == "swift" {
                let source = try String(contentsOf: file, encoding: .utf8)
                guard source.contains("AppIntent") || source.contains("AppEnum") else { continue }
                let ns = source as NSString
                for match in Self.metadataLiteral.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
                    strings.append(ns.substring(with: match.range(at: 1)))
                }
            }
        }
        return strings
    }

    private func translations(of key: String) throws -> [String] {
        var values: [String] = []
        for catalog in Self.catalogs {
            let url = Self.repoRoot.appendingPathComponent(catalog)
            guard let data = try? Data(contentsOf: url),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any],
                  let entry = strings[key] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { continue }
            for case let localization as [String: Any] in localizations.values {
                if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
                    values.append(value)
                }
            }
        }
        return values
    }

    @Test("Intent metadata never names an Apple device, in any language")
    func noAppleDeviceNames() throws {
        let strings = try metadataStrings()
        #expect(strings.contains { $0.hasPrefix("Records the income or expense") }, "Scanner found no bank-alert description; is the pattern right?")

        var offenders: [String] = []
        for string in strings {
            for text in [string] + (try translations(of: string)) {
                let lower = text.lowercased()
                if let word = Self.banned.first(where: { lower.contains($0) }) {
                    offenders.append("'\(word)' in: \(text)")
                }
            }
        }
        #expect(offenders.isEmpty, "App Store Connect rejects these (ITMS-90626):\n\(offenders.joined(separator: "\n"))")
    }
}
